import 'dart:convert';

import 'package:app/features/auth/presentation/login_view.dart';
import 'package:app/features/onboarding/presentation/location_permission_view.dart';
import 'package:app/features/tracking/data/pickup_tracking_controller.dart';
import 'package:app/features/tracking/domain/pickup_tracking_state.dart';
import 'package:app/features/tracking/domain/tracking_timeline.dart';
import 'package:app/features/tracking/presentation/tracking_view.dart';
import 'package:app/models/pickup.dart';
import 'package:app/repositories/pickup_repository.dart';
import 'package:app/services/api_result.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geofence_contract/geofence_contract.dart';
import 'package:http/http.dart' as http;

import 'support/test_harness.dart';

/// Replaces the device GPS in tests.
class FakeLocationService implements LocationService {
  LocationOutcome outcome;
  LocationIssue? permissionIssue;
  final List<LocationIssue> settingsOpened = [];
  int fixRequests = 0;

  FakeLocationService(this.outcome, {this.permissionIssue});

  @override
  Future<LocationIssue?> ensurePermission() async => permissionIssue;

  @override
  Future<LocationOutcome> getCurrentFix() async {
    fixRequests++;
    return outcome;
  }

  @override
  Future<bool> openSettingsFor(LocationIssue issue) async {
    settingsOpened.add(issue);
    return true;
  }
}

/// A backend that (hypothetically) supports verified collector events.
/// Delegates the verified endpoints to the real HTTP implementation.
class EventsCapableRepository implements PickupRepository {
  final HttpPickupRepository _http = const HttpPickupRepository();
  List<GeofenceEvent> events;
  int eventRequests = 0;

  EventsCapableRepository(this.events);

  @override
  PickupCapabilities get capabilities =>
      const PickupCapabilities(verifiedEvents: true);

  @override
  Future<ApiResult<ActivePickup>> getActivePickup() => _http.getActivePickup();
  @override
  Future<ApiResult<CreatedPickup>> createPickup(CreatePickupRequest r) =>
      _http.createPickup(r);
  @override
  Future<ApiResult<void>> updatePickupStatus(UpdatePickupStatusRequest r) =>
      _http.updatePickupStatus(r);
  @override
  Future<ApiResult<List<GeofenceEvent>>> getVerifiedEvents(String id) async {
    eventRequests++;
    return ApiResult.success(events);
  }

  @override
  Future<ApiResult<PickupRecord>> getPickup(String id) => _http.getPickup(id);
  @override
  Future<ApiResult<List<PickupRecord>>> getPickupHistory() =>
      _http.getPickupHistory();
  @override
  Future<ApiResult<void>> cancelPickup(String id) => _http.cancelPickup(id);
  @override
  Future<ApiResult<Geofence>> getGeofence(String id) => _http.getGeofence(id);
}

LocationFix fixAt(double lat, double lng, {double? acc = 12}) => LocationFix(
      point: GeoPoint(lat, lng),
      accuracyMeters: acc,
      capturedAt: DateTime(2026, 11, 1, 12),
    );

GeofenceEvent event(String id, GeofenceEventType type,
        {GeofenceEventSource source = GeofenceEventSource.backend,
        String pickupId = '7',
        int minute = 0}) =>
    GeofenceEvent(
      eventId: id,
      pickupId: pickupId,
      type: type,
      occurredAt: DateTime.utc(2026, 11, 2, 7, minute),
      source: source,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prepared repository integration points', () {
    test('unsupported capabilities send nothing and never fake success',
        () async {
      final backend = setUpFakes(token: fakeJwt());
      const repo = HttpPickupRepository();

      final results = <ApiResult<Object?>>[
        await repo.getPickup('1'),
        await repo.getPickupHistory(),
        await repo.cancelPickup('1'),
        await repo.getGeofence('1'),
        await repo.getVerifiedEvents('1'),
      ];
      for (final r in results) {
        expect(r.isSuccess, isFalse);
        expect(r.isNotSupported, isTrue);
        expect(r.errorMessage, contains('not supported by the backend yet'));
      }
      expect(backend.requests, isEmpty);
      expect(repo.capabilities.verifiedEvents, isFalse);
    });

    test('with the current backend the controller never asks for events',
        () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('7', 200);
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await c.read(pickupTrackingProvider.notifier).sync();
      final s = c.read(pickupTrackingProvider);
      expect(s.collectorEventsSupported, isFalse);
      expect(s.verifiedEvents, isEmpty);
      // Collector stages are "not reported", not "upcoming".
      final steps = buildTimeline(s);
      expect(
        steps.firstWhere((x) => x.id == TrackingStageId.arrived).status,
        StageStatus.notReported,
      );
    });
  });

  group('Verified geofence events -> tracking (single state machine)', () {
    test('backend/collector events confirm stages; resident events are ignored',
        () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('7', 200);
      final repo = EventsCapableRepository([
        event('a', GeofenceEventType.collectorAssigned, minute: 1),
        event('b', GeofenceEventType.geofenceEntered,
            source: GeofenceEventSource.collector, minute: 5),
        // The resident's own phone is never proof of arrival.
        event('c', GeofenceEventType.collectorArrived,
            source: GeofenceEventSource.resident, minute: 6),
        // Events for another pickup are ignored.
        event('d', GeofenceEventType.collectorArrived, pickupId: '8', minute: 7),
      ]);
      final c = ProviderContainer(
          overrides: [pickupRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);

      await c.read(pickupTrackingProvider.notifier).sync();
      final s = c.read(pickupTrackingProvider);
      expect(s.verifiedEvents.map((e) => e.eventId), ['a', 'b']);

      final steps = buildTimeline(s);
      TrackingStep step(TrackingStageId id) =>
          steps.firstWhere((x) => x.id == id);
      // collectorAssigned / collectorEnRoute stages have been removed from
      // the timeline. Events 'a' and 'b' now produce no confirmed stage;
      // 'confirmed' remains the current stage and 'arrived' is upcoming.
      expect(step(TrackingStageId.confirmed).status, StageStatus.current);
      expect(step(TrackingStageId.arrived).status, StageStatus.upcoming);
      // The pickup phase is still governed by the backend status only.
      expect(s.isActive, isTrue);

      // A later poll brings verified arrival; the current stage moves on.
      repo.events = [
        ...repo.events,
        event('e', GeofenceEventType.collectorArrived, minute: 9),
      ];
      await c.read(pickupTrackingProvider.notifier).sync();
      final later = buildTimeline(c.read(pickupTrackingProvider));
      expect(currentStep(later)!.id, TrackingStageId.arrived);
      expect(repo.eventRequests, 2);
    });

    test('verified collection does not complete the pickup by itself', () {
      final steps = buildTimeline(PickupTrackingState(
        phase: PickupPhase.active,
        pickupId: '7',
        collectorEventsSupported: true,
        verifiedEvents: [event('x', GeofenceEventType.collectionCompleted)],
      ));
      expect(
        steps.firstWhere((s) => s.id == TrackingStageId.wasteCollected).status,
        StageStatus.current,
      );
      expect(
        steps.firstWhere((s) => s.id == TrackingStageId.completed).status,
        StageStatus.upcoming,
      );
    });
  });

  group('Local pickup details', () {
    test('location and accuracy persist; malformed storage is tolerated',
        () async {
      setUpFakes(token: fakeJwt());
      await AuthService.savePickupDetails(LocalPickupDetails(
        pickupId: '9',
        requestDate: DateTime(2026, 11, 3),
        location: GeoPoint(15.49, 73.82),
        locationAccuracyMeters: 7.5,
      ));
      final back = await AuthService.getPickupDetails();
      expect(back!.location, GeoPoint(15.49, 73.82));
      expect(back.locationAccuracyMeters, 7.5);

      expect(LocalPickupDetails.fromJson({'pickupId': ''}), isNull);
      expect(
        LocalPickupDetails.fromJson({'pickupId': 'x', 'lat': 999, 'lng': 0})!
            .location,
        isNull,
      );

      await AuthService.clearPickupId();
      expect(await AuthService.getPickupDetails(), isNull);
    });
  });

  group('Scheduling with the location service', () {
    Future<(FakeBackend, FakeLocationService)> openSchedule(
      WidgetTester tester,
      LocationOutcome outcome,
    ) async {
      final backend = setUpFakes(token: fakeJwt());
      final location = FakeLocationService(outcome);
      await pumpApp(
        tester,
        initialRoute: '/home',
        overrides: [locationServiceProvider.overrideWithValue(location)],
      );
      await settle(tester);
      await tapOn(tester, find.text('SCHEDULE PICKUP'));
      await settle(tester);
      return (backend, location);
    }

    testWidgets('sends the captured position and shows it in tracking',
        (tester) async {
      final (backend, _) = await openSchedule(
          tester, LocationOutcome.success(fixAt(15.49091, 73.82782)));

      await tapOn(tester, find.text('CONFIRM REQUEST'));
      await settle(tester);

      final body = jsonDecode(backend.requestsTo('POST', '/pickups').single.body);
      expect(body['latitude'], 15.49091);
      expect(body['longitude'], 73.82782);
      // No fields beyond the verified contract are sent.
      expect((body as Map).keys.toSet(), {'requestDate', 'latitude', 'longitude'});

      await tapOn(tester, find.text('TRACK PICKUP'));
      await settle(tester);
      expect(find.byType(TrackingView), findsOneWidget);
      final location = find.text('15.49091, 73.82782 · ±12 m');
      await tester.scrollUntilVisible(location, 200,
          scrollable: find
              .descendant(
                  of: find.byType(TrackingView), matching: find.byType(Scrollable))
              .first);
      expect(location, findsOneWidget);
    });

    testWidgets('location services off: explains, offers Settings, sends nothing',
        (tester) async {
      final (backend, location) = await openSchedule(tester,
          const LocationOutcome.failure(LocationIssue.serviceDisabled));

      await tapOn(tester, find.text('CONFIRM REQUEST'));
      await settle(tester);

      expect(find.textContaining('Location services (GPS) are turned off'),
          findsOneWidget);
      await tester.tap(find.text('SETTINGS'));
      await settle(tester, frames: 3);
      expect(location.settingsOpened, [LocationIssue.serviceDisabled]);
      expect(backend.requestsTo('POST', '/pickups'), isEmpty);
    });

    testWidgets('inaccurate fix is refused with the reported accuracy',
        (tester) async {
      final (backend, _) = await openSchedule(
        tester,
        LocationOutcome.failure(LocationIssue.inaccurate,
            fix: fixAt(15.49, 73.82, acc: 1800)),
      );

      await tapOn(tester, find.text('CONFIRM REQUEST'));
      await settle(tester);

      expect(find.textContaining('±1800 m'), findsOneWidget);
      expect(backend.requestsTo('POST', '/pickups'), isEmpty);
      expect(find.text('CONFIRM REQUEST'), findsOneWidget);
    });
  });

  group('Onboarding location permission', () {
    testWidgets('denied: stays and explains; granted: continues to login',
        (tester) async {
      setUpFakes();
      final location = FakeLocationService(
        const LocationOutcome.failure(LocationIssue.unavailable),
        permissionIssue: LocationIssue.permissionDenied,
      );
      await pumpApp(tester,
          initialRoute: '/location-permission',
          overrides: [locationServiceProvider.overrideWithValue(location)]);
      await settle(tester);

      await tapOn(tester, find.text('ALLOW LOCATION'));
      await settle(tester);
      expect(find.text('Location permission denied'), findsOneWidget);
      expect(find.byType(LocationPermissionView), findsOneWidget);
      // Onboarding never reads the position itself.
      expect(location.fixRequests, 0);

      location.permissionIssue = null;
      await tapOn(tester, find.text('ALLOW LOCATION'));
      await settle(tester);
      expect(find.byType(LoginView), findsOneWidget);
    });
  });
}
