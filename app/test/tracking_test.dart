import 'dart:async';
import 'dart:convert';

import 'package:app/core/config/api_config.dart';
import 'package:app/features/dashboard/presentation/dashboard_view.dart';
import 'package:app/features/main/data/navigation_provider.dart';
import 'package:app/features/profile/presentation/profile_view.dart';
import 'package:app/features/rewards/presentation/rewards_view.dart';
import 'package:app/features/schedule/presentation/schedule_view.dart';
import 'package:app/features/tracking/data/pickup_tracking_controller.dart';
import 'package:app/features/tracking/domain/pickup_tracking_state.dart';
import 'package:app/features/tracking/domain/tracking_timeline.dart';
import 'package:app/features/tracking/presentation/tracking_view.dart';
import 'package:app/models/pickup.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/services/location_service.dart';
import 'package:geofence_contract/geofence_contract.dart';
import 'package:app/shared/widgets/pill_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/test_harness.dart';

LocationFix testFix([double lat = 15.49091, double lng = 73.82782, double? acc = 12]) =>
    LocationFix(
      point: GeoPoint(lat, lng),
      accuracyMeters: acc,
      capturedAt: DateTime(2026, 11, 1, 12),
    );

Finder onStage(Finder finder) => find.descendant(
      of: find.byType(Navigator),
      matching: finder,
      skipOffstage: true,
    );

List<StageStatus> statuses(List<TrackingStep> steps) =>
    steps.map((s) => s.status).toList();

/// The tracking screen is a lazily built list; scroll [finder] into view.
Future<void> scrollTracking(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(of: find.byType(TrackingView), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pump();
}

TrackingStep stepById(List<TrackingStep> steps, TrackingStageId id) =>
    steps.firstWhere((s) => s.id == id);

void main() {
  // ---------------------------------------------------------------------------
  // Mapping layer: backend facts -> timeline
  // ---------------------------------------------------------------------------
  group('Timeline mapping', () {
    final requestedAt = DateTime(2026, 11, 1, 9, 30);

    test('no pickup -> no timeline', () {
      expect(buildTimeline(const PickupTrackingState()), isEmpty);
    });

    test('active: confirmed is current, unsupported stages are never done', () {
      final steps = buildTimeline(PickupTrackingState(
        phase: PickupPhase.active,
        pickupId: '1',
        requestedAt: requestedAt,
      ));

      expect(statuses(steps), [
        StageStatus.done, // requested
        StageStatus.current, // confirmed
        StageStatus.notReported, // collector assigned
        StageStatus.notReported, // en route
        StageStatus.notReported, // arrived
        StageStatus.upcoming, // waste collected
        StageStatus.upcoming, // completed
      ]);
      expect(currentStep(steps)!.id, TrackingStageId.confirmed);
      expect(stepById(steps, TrackingStageId.requested).time, requestedAt);
      // Not-reported stages carry no time (nothing fabricated).
      for (final s in steps.where((s) => s.status == StageStatus.notReported)) {
        expect(s.time, isNull);
      }
    });

    test('restored pickup (created elsewhere) has no invented timestamps', () {
      final steps = buildTimeline(const PickupTrackingState(
        phase: PickupPhase.active,
        pickupId: '1',
      ));
      expect(steps.every((s) => s.time == null), isTrue);
    });

    test('COMPLETED: collected + completed done, completed is current', () {
      final resolvedAt = DateTime(2026, 11, 2, 8);
      final steps = buildTimeline(PickupTrackingState(
        phase: PickupPhase.completed,
        pickupId: '1',
        resolvedAt: resolvedAt,
      ));
      expect(stepById(steps, TrackingStageId.wasteCollected).status,
          StageStatus.done);
      expect(currentStep(steps)!.id, TrackingStageId.completed);
      expect(currentStep(steps)!.time, resolvedAt);
    });

    test('FAILED maps to "Not Collected", never to completed', () {
      final steps = buildTimeline(const PickupTrackingState(
        phase: PickupPhase.notCollected,
        pickupId: '1',
      ));
      expect(currentStep(steps)!.id, TrackingStageId.notCollected);
      expect(currentStep(steps)!.isNegative, isTrue);
      expect(steps.any((s) => s.id == TrackingStageId.completed), isFalse);
    });

    test('server closed it without a reported outcome -> not shown completed',
        () {
      final steps = buildTimeline(const PickupTrackingState(
        phase: PickupPhase.closed,
        pickupId: '1',
      ));
      expect(currentStep(steps)!.id, TrackingStageId.closed);
      expect(steps.any((s) => s.id == TrackingStageId.completed), isFalse);
    });

    test('backend status strings map to phases', () {
      expect(backendStatusToPhase[PickupStatus.completed], PickupPhase.completed);
      expect(backendStatusToPhase[PickupStatus.failed], PickupPhase.notCollected);
    });
  });

  // ---------------------------------------------------------------------------
  // Controller: state transitions against the (fake) backend contract
  // ---------------------------------------------------------------------------
  group('PickupTrackingController', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    ProviderContainer makeContainer() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('sync restores an active pickup from the server (no local details)',
        () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('77', 200);
      final c = makeContainer();

      await c.read(pickupTrackingProvider.notifier).sync();
      final s = c.read(pickupTrackingProvider);

      expect(s.phase, PickupPhase.active);
      expect(s.pickupId, '77');
      expect(s.requestDate, isNull); // not returned by backend -> not invented
      expect(s.lastSyncedAt, isNotNull);
      expect(await AuthService.getPickupId(), '77');
    });

    test('create stores the chosen date; duplicates are never created',
        () async {
      final backend = setUpFakes(token: fakeJwt());
      final c = makeContainer();
      final notifier = c.read(pickupTrackingProvider.notifier);
      final date = DateTime(2026, 11, 3);

      final first = await notifier.create(
          requestDate: date, location: testFix());
      expect(first.data, '42');
      final s = c.read(pickupTrackingProvider);
      expect(s.phase, PickupPhase.active);
      expect(s.requestDate, date);
      expect(s.requestedAt, isNotNull);

      // A second create (double tap / re-navigation) does not POST again.
      final second = await notifier.create(
          requestDate: date, location: testFix());
      expect(second.data, '42');
      expect(backend.requestsTo('POST', '/pickups'), hasLength(1));
    });

    test('details survive an app restart for the same pickup', () async {
      final backend = setUpFakes(token: fakeJwt());
      final date = DateTime(2026, 11, 4);
      final c1 = makeContainer();
      await c1
          .read(pickupTrackingProvider.notifier)
          .create(requestDate: date, location: testFix());

      // "Restart": fresh in-memory state, same secure storage.
      backend.activePickup = (_) => http.Response('42', 200);
      final c2 = makeContainer();
      await c2.read(pickupTrackingProvider.notifier).sync();
      expect(c2.read(pickupTrackingProvider).requestDate, date);
    });

    test('403 on create returns the existing pickup without attributing the '
        'new date to it', () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.createPickup = (_) => http.Response('', 403);
      backend.activePickup = (_) => http.Response('9', 200);
      final c = makeContainer();

      final result = await c.read(pickupTrackingProvider.notifier).create(
          requestDate: DateTime(2026, 11, 3), location: testFix());

      expect(result.data, '9');
      expect(c.read(pickupTrackingProvider).requestDate, isNull);
    });

    test('server stops listing the pickup -> "closed", NOT completed', () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('5', 200);
      final c = makeContainer();
      final notifier = c.read(pickupTrackingProvider.notifier);
      await notifier.sync();

      backend.activePickup = (_) => http.Response('', 200);
      await notifier.sync();

      final s = c.read(pickupTrackingProvider);
      expect(s.phase, PickupPhase.closed);
      expect(s.phase, isNot(PickupPhase.completed));
      expect(s.isActive, isFalse);
      expect(await AuthService.getPickupId(), isNull);
    });

    test('failed sync keeps the last known state and reports the error',
        () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('5', 200);
      final c = makeContainer();
      final notifier = c.read(pickupTrackingProvider.notifier);
      await notifier.sync();
      final before = c.read(pickupTrackingProvider).lastSyncedAt;

      backend.activePickup = (_) => throw http.ClientException('offline');
      await notifier.sync();
      var s = c.read(pickupTrackingProvider);
      expect(s.phase, PickupPhase.active);
      expect(s.pickupId, '5');
      expect(s.syncError, contains('Unable to reach the server'));
      expect(s.lastSyncedAt, before);
      expect(s.isSyncing, isFalse);

      backend.activePickup = (_) => http.Response('5', 200);
      await notifier.sync();
      s = c.read(pickupTrackingProvider);
      expect(s.syncError, isNull);
    });

    test('resolve COMPLETED / FAILED moves to the matching final phase',
        () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('5', 200);
      final c = makeContainer();
      final notifier = c.read(pickupTrackingProvider.notifier);
      await notifier.sync();

      final r = await notifier.resolve(PickupStatus.completed, points: 10);
      expect(r.isSuccess, isTrue);
      expect(c.read(pickupTrackingProvider).phase, PickupPhase.completed);
      expect(jsonDecode(backend.requests.last.body)['pickupId'], '5');

      // Can't resolve twice.
      final again = await notifier.resolve(PickupStatus.failed);
      expect(again.isSuccess, isFalse);
      expect(backend.requestsTo('PUT', '/pickups/status'), hasLength(1));
    });

    test('failed status update keeps the pickup active', () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('5', 200);
      backend.pickupStatus = (_) => http.Response('err', 500);
      final c = makeContainer();
      final notifier = c.read(pickupTrackingProvider.notifier);
      await notifier.sync();

      final r = await notifier.resolve(PickupStatus.completed, points: 10);
      expect(r.isSuccess, isFalse);
      expect(c.read(pickupTrackingProvider).phase, PickupPhase.active);
      expect(await AuthService.getPickupId(), '5');
    });

    test('a sync that started before a status update cannot overwrite it',
        () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('5', 200);
      final c = makeContainer();
      final notifier = c.read(pickupTrackingProvider.notifier);
      await notifier.sync();

      // Hold a sync in flight that will (stale) report the pickup as active.
      final gate = Completer<void>();
      backend.activeGate = gate;
      final pending = notifier.sync();
      await Future<void>.delayed(Duration.zero);

      backend.activeGate = null;
      await notifier.resolve(PickupStatus.failed);
      expect(c.read(pickupTrackingProvider).phase, PickupPhase.notCollected);

      // Release the stale response.
      gate.complete();
      await pending;
      expect(c.read(pickupTrackingProvider).phase, PickupPhase.notCollected);
      expect(c.read(pickupTrackingProvider).isSyncing, isFalse);
    });

    test('concurrent syncs share one request', () async {
      final backend = setUpFakes(token: fakeJwt());
      final c = makeContainer();
      final notifier = c.read(pickupTrackingProvider.notifier);
      await Future.wait([notifier.sync(), notifier.sync(), notifier.sync()]);
      expect(backend.requestsTo('GET', '/pickups/active'), hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Tracking screen
  // ---------------------------------------------------------------------------
  group('Tracking screen', () {
    Future<FakeBackend> openHomeWithActive(WidgetTester tester,
        {String id = '55'}) async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response(id, 200);
      await pumpApp(tester, initialRoute: '/home');
      await settle(tester);
      return backend;
    }

    Future<void> openTrackingFromHome(WidgetTester tester) async {
      await tapOn(tester, find.widgetWithText(ElevatedButton, 'TRACK PICKUP'));
      await settle(tester);
      expect(find.byType(TrackingView), findsOneWidget);
    }

    testWidgets('opens the correct request from Home and shows the timeline',
        (tester) async {
      await openHomeWithActive(tester, id: '55');
      await openTrackingFromHome(tester);

      // Every built connector line between stages is actually visible.
      final connectors = find.byWidgetPredicate((w) =>
          w is AnimatedContainer && w.constraints?.maxWidth == 2);
      expect(connectors, findsWidgets);
      for (final e in connectors.evaluate()) {
        expect(e.size!.height, greaterThan(12));
      }

      final semantics = tester.ensureSemantics();
      final expected = {
        'Pickup Requested': 'completed',
        'Request Confirmed': 'current',
        'Collector Assigned': 'not reported by the server',
        'Collector En Route': 'not reported by the server',
        'Pickup Arrived': 'not reported by the server',
        'Waste Collected': 'upcoming',
        'Pickup Completed': 'upcoming',
      };
      for (final e in expected.entries) {
        final label = find.bySemanticsLabel(RegExp('^${e.key}: ${e.value}'));
        await scrollTracking(tester, label);
        expect(label, findsOneWidget, reason: e.key);
      }
      semantics.dispose();

      await scrollTracking(tester, find.text('#55'));
      expect(find.text('#55'), findsOneWidget);
      // Unavailable data is labelled, not invented.
      expect(find.text('Not provided by server'), findsNWidgets(2));
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('PICKED UP'), findsOneWidget);
    });

    testWidgets('polls while open, reflects a server-side change, and stops '
        'polling once closed', (tester) async {
      final backend = await openHomeWithActive(tester);
      await openTrackingFromHome(tester);
      int polls() => backend.requestsTo('GET', '/pickups/active').length;

      final afterOpen = polls();
      await tester.pump(ApiConfig.trackingPollInterval);
      await settle(tester, frames: 5);
      expect(polls(), afterOpen + 1);

      // Server closes the pickup (e.g. handled by the municipality).
      backend.activePickup = (_) => http.Response('', 200);
      await tester.pump(ApiConfig.trackingPollInterval);
      await settle(tester);
      expect(onStage(find.text('No Longer Active')), findsWidgets);
      expect(find.text('Pickup Completed'), findsNothing);
      expect(find.text('DONE'), findsOneWidget);

      // No polling for a pickup that is no longer active.
      final afterClose = polls();
      await tester.pump(ApiConfig.trackingPollInterval * 2);
      await settle(tester, frames: 5);
      expect(polls(), afterClose);
    });

    testWidgets('polling stops when the screen is closed', (tester) async {
      final backend = await openHomeWithActive(tester);
      await openTrackingFromHome(tester);

      await tapOn(tester, find.byType(BackButton));
      await settle(tester);
      final afterClose = backend.requestsTo('GET', '/pickups/active').length;

      await tester.pump(ApiConfig.trackingPollInterval * 3);
      await settle(tester, frames: 5);
      expect(backend.requestsTo('GET', '/pickups/active').length, afterClose);
    });

    testWidgets('backend unavailable: last known status stays, banner shown',
        (tester) async {
      final backend = await openHomeWithActive(tester);
      await openTrackingFromHome(tester);

      backend.activePickup = (_) => throw http.ClientException('offline');
      await tester.pump(ApiConfig.trackingPollInterval);
      await settle(tester);

      expect(find.textContaining("Couldn't refresh"), findsOneWidget);
      expect(find.text('Request Confirmed'), findsWidgets);
      await scrollTracking(tester, find.text('#55'));
      expect(find.text('#55'), findsOneWidget);
      expect(find.text('PICKED UP'), findsOneWidget);
    });

    testWidgets('PICKED UP on the tracking screen completes the timeline',
        (tester) async {
      final backend = await openHomeWithActive(tester);
      await openTrackingFromHome(tester);

      await tapOn(tester, find.text('PICKED UP'));
      await settle(tester);

      expect(backend.requestsTo('PUT', '/pickups/status'), hasLength(1));
      expect(find.text('Pickup Completed'), findsWidgets);
      expect(find.text('DONE'), findsOneWidget);

      await tapOn(tester, find.text('DONE'));
      await settle(tester);
      // Home no longer treats it as active; scheduling is available again.
      expect(onStage(find.byType(DashboardView)), findsOneWidget);
      expect(find.text('SCHEDULE PICKUP'), findsOneWidget);
      expect(find.text('NO ACTIVE ACTIVITY'), findsOneWidget);
    });

    testWidgets('a different request id is never shown as the active one',
        (tester) async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('55', 200);
      await pumpApp(tester, initialRoute: '/home');
      await settle(tester);

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed('/track', arguments: '999');
      await settle(tester);

      expect(find.text('Tracking unavailable'), findsOneWidget);
      expect(find.text('#55'), findsNothing);
    });

    testWidgets('confirmation view (Requests tab) opens tracking for that '
        'request', (tester) async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('', 200);
      final container = await pumpApp(tester, initialRoute: '/home');
      await settle(tester);

      // Simulate the post-scheduling state for pickup 42 created on this device.
      await container.read(pickupTrackingProvider.notifier).create(
          requestDate: DateTime.now().add(const Duration(days: 1)),
          location: testFix());
      container.read(navigationProvider.notifier).state = 1;
      await settle(tester);

      expect(onStage(find.text('Pickup Requested\nSuccessfully!')), findsOneWidget);
      await tapOn(tester, onStage(find.text('TRACK PICKUP')).first);
      await settle(tester);

      expect(find.byType(TrackingView), findsOneWidget);
      await scrollTracking(tester, find.text('#42'));
      expect(find.text('#42'), findsOneWidget);
      // The date the resident chose is shown (not fabricated).
      expect(find.textContaining('7 AM - 10 AM'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Bottom navigation + FAB layout
  // ---------------------------------------------------------------------------
  group('Bottom navigation layout', () {
    const sizes = <String, Size>{
      'small 320x568': Size(320, 568),
      'common 393x852': Size(393, 852),
      'tall 412x915': Size(412, 915),
    };
    const insets = <String, double>{
      'no inset': 0,
      'gesture nav': 24,
      '3-button nav': 48,
    };

    for (final size in sizes.entries) {
      for (final inset in insets.entries) {
        testWidgets('${size.key}, ${inset.key}: bar fixed above system nav, '
            'FAB above bar, content not covered', (tester) async {
          setUpFakes(token: fakeJwt());
          await pumpApp(tester,
              initialRoute: '/home',
              logicalSize: size.value,
              bottomInset: inset.value);
          await settle(tester);

          final screenH = size.value.height;
          final bar = tester.getRect(find.byType(PillNavigationBar));
          final fab = tester.getRect(find.byType(FloatingActionButton));
          final body = tester.getRect(find.byType(IndexedStack));

          // Bar is at the bottom and clear of the system navigation area.
          expect(bar.bottom, lessThanOrEqualTo(screenH - inset.value));
          expect(bar.bottom, greaterThan(screenH - inset.value - 40));
          // FAB fully visible above the bar.
          expect(fab.bottom, lessThanOrEqualTo(bar.top));
          expect(fab.top, greaterThan(0));
          // Body ends where the bar starts (bar never covers content).
          expect(body.bottom, lessThanOrEqualTo(bar.top));

          // Scrolling the content does not move the bar.
          await tester.drag(
              onStage(find.byType(SingleChildScrollView)).first,
              const Offset(0, -400));
          await settle(tester, frames: 5);
          expect(tester.getRect(find.byType(PillNavigationBar)), bar);
        });
      }
    }

    testWidgets('each nav item opens its tab and is marked selected',
        (tester) async {
      setUpFakes(token: fakeJwt());
      final container = await pumpApp(tester, initialRoute: '/home');
      await settle(tester);

      Finder item(IconData icon) => find.descendant(
          of: find.byType(PillNavigationBar), matching: find.byIcon(icon));

      final expected = <IconData, (int, Type)>{
        Icons.calendar_today: (1, ScheduleView),
        Icons.military_tech: (2, RewardsView),
        Icons.person: (3, ProfileView),
      };
      for (final e in expected.entries) {
        await tapOn(tester, item(e.key));
        await settle(tester);
        expect(container.read(navigationProvider), e.value.$1);
        expect(onStage(find.byType(e.value.$2)), findsOneWidget);
      }

      await tapOn(tester, item(Icons.home_max));
      await settle(tester);
      expect(container.read(navigationProvider), 0);
      expect(onStage(find.byType(DashboardView)), findsOneWidget);
      // Tab switching never pushes routes.
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse);
    });

    testWidgets('FAB switches to Track Pickup while a pickup is active and '
        'never offers a second schedule', (tester) async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('55', 200);
      await pumpApp(tester, initialRoute: '/home');
      await settle(tester);

      final fab = find.byType(FloatingActionButton);
      expect(find.descendant(of: fab, matching: find.text('TRACK PICKUP')),
          findsOneWidget);
      expect(find.text('SCHEDULE PICKUP'), findsNothing);

      await tapOn(tester, fab);
      await settle(tester);
      expect(find.byType(TrackingView), findsOneWidget);
      await scrollTracking(tester, find.text('#55'));
      expect(find.text('#55'), findsOneWidget);
      expect(backend.requestsTo('POST', '/pickups'), isEmpty);
    });
  });
}
