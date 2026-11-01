import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geofence_contract/geofence_contract.dart';
import 'package:intl/intl.dart';

import '../../../models/pickup.dart';
import '../../../repositories/pickup_repository.dart';
import '../../../services/api_result.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import '../../profile/data/profile_provider.dart';
import '../domain/pickup_tracking_state.dart';
import '../domain/tracking_timeline.dart';

/// Single source of truth for the resident's pickup.
///
/// Every screen (Home, Requests tab, confirmation, tracking) reads this
/// provider, and every pickup API call that changes state goes through this
/// controller, so screens cannot disagree or create duplicate pickups.
final pickupTrackingProvider =
    NotifierProvider<PickupTrackingController, PickupTrackingState>(
  PickupTrackingController.new,
);

class PickupTrackingController extends Notifier<PickupTrackingState> {
  /// Shared future for an in-flight sync so overlapping callers (Home load,
  /// tracking poll, app resume) result in a single request.
  Future<void>? _syncInFlight;

  /// Incremented by every create / status update. A sync that started before
  /// a mutation must not overwrite the mutation's result with stale data.
  int _generation = 0;

  bool _mutating = false;

  PickupRepository get _repo => ref.read(pickupRepositoryProvider);

  @override
  PickupTrackingState build() => PickupTrackingState(
        collectorEventsSupported:
            ref.read(pickupRepositoryProvider).capabilities.verifiedEvents,
      );

  bool get _eventsSupported => _repo.capabilities.verifiedEvents;

  /// Re-reads `GET /pickups/active` (and verified events, when the backend
  /// supports them) and updates the state.
  ///
  /// On failure the last known state is kept and [PickupTrackingState.syncError]
  /// is set.
  Future<void> sync() {
    return _syncInFlight ??= _sync().whenComplete(() => _syncInFlight = null);
  }

  Future<void> _sync() async {
    // Hop off the current synchronous frame so callers may trigger a sync from
    // widget lifecycle methods without modifying a provider during build.
    await Future<void>.microtask(() {});
    if (!ref.mounted) return;
    try {
      await _syncBody();
    } finally {
      // Covers every early return (stale generation, unmounted widget, etc.).
      if (ref.mounted && state.isSyncing) {
        state = state.copyWith(isSyncing: false);
      }
    }
  }

  Future<void> _syncBody() async {
    final generation = _generation;
    state = state.copyWith(isSyncing: true);

    final result = await _repo.getActivePickup();
    if (!ref.mounted || generation != _generation) return;

    if (!result.isSuccess) {
      state = state.copyWith(isSyncing: false, syncError: result.errorMessage);
      return;
    }

    final now = DateTime.now();
    final active = result.data!;

    if (active.isActive) {
      final events = await _fetchVerifiedEvents(active.pickupId!);
      if (!ref.mounted || generation != _generation) return;

      if (state.isActive && state.pickupId == active.pickupId) {
        state = state.copyWith(
          verifiedEvents: events,
          isSyncing: false,
          lastSyncedAt: now,
          clearSyncError: true,
        );
        return;
      }

      // An active pickup we are not tracking yet (app start, re-login, or
      // created on another device). Use locally stored details only if they
      // belong to this exact pickup id.
      final local = await AuthService.getPickupDetails();
      if (!ref.mounted || generation != _generation) return;
      final details = (local != null && local.pickupId == active.pickupId)
          ? local
          : LocalPickupDetails(pickupId: active.pickupId!);
      if (!identical(details, local)) {
        await AuthService.savePickupDetails(details);
        if (!ref.mounted || generation != _generation) return;
      }

      state = _activeState(details, events: events ?? const [], syncedAt: now);
      return;
    }

    // The server reports no active pickup.
    await AuthService.clearPickupId();
    if (!ref.mounted || generation != _generation) return;

    if (state.isActive) {
      // We were tracking a pickup and this device did not report its
      // outcome. Do NOT assume it was completed.
      state = state.copyWith(
        phase: PickupPhase.closed,
        resolvedAt: now,
        lastSyncedAt: now,
        isSyncing: false,
        clearSyncError: true,
      );
      // Points / last pickup may have changed server-side.
      ref.invalidate(userProfileProvider);
      return;
    }

    state = state.copyWith(
      isSyncing: false,
      lastSyncedAt: now,
      clearSyncError: true,
    );
  }

  /// Verified collector/backend events, or null when unsupported or the
  /// request failed (the previous events are then kept).
  Future<List<GeofenceEvent>?> _fetchVerifiedEvents(String pickupId) async {
    if (!_eventsSupported) return null;
    final result = await _repo.getVerifiedEvents(pickupId);
    if (!result.isSuccess) return null;
    // Resident-sourced events are never treated as collector progress.
    return result.data!
        .where((e) =>
            e.pickupId == pickupId && e.source != GeofenceEventSource.resident)
        .toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  }

  PickupTrackingState _activeState(
    LocalPickupDetails details, {
    required List<GeofenceEvent> events,
    required DateTime syncedAt,
  }) {
    return PickupTrackingState(
      phase: PickupPhase.active,
      pickupId: details.pickupId,
      requestDate: details.requestDate,
      requestedAt: details.requestedAt,
      pickupLocation: details.location,
      pickupLocationAccuracyMeters: details.locationAccuracyMeters,
      verifiedEvents: events,
      collectorEventsSupported: _eventsSupported,
      lastSyncedAt: syncedAt,
    );
  }

  /// Creates a pickup for [requestDate] at [location] (the resident's current
  /// position, captured by [LocationService]).
  ///
  /// If a pickup is already active, no request is sent and the existing id is
  /// returned, so navigation or repeated taps can never create duplicates.
  Future<ApiResult<String>> create({
    required DateTime requestDate,
    required LocationFix location,
  }) async {
    if (state.isActive && state.pickupId != null) {
      return ApiResult.success(state.pickupId!);
    }
    if (_mutating) {
      return const ApiResult.failure('Please wait, a request is in progress.');
    }
    _mutating = true;
    _generation++;

    try {
      final result = await _repo.createPickup(
        CreatePickupRequest(
          requestDate: DateFormat('yyyy-MM-dd').format(requestDate),
          latitude: location.point.latitude,
          longitude: location.point.longitude,
        ),
      );
      if (!ref.mounted || !result.isSuccess) return _asIdResult(result);

      final created = result.data!;
      final now = DateTime.now();

      LocalPickupDetails details;
      if (created.alreadyExisted) {
        // An earlier pickup is still active: keep only details that were
        // recorded for that exact pickup.
        final local = await AuthService.getPickupDetails();
        details = (local != null && local.pickupId == created.pickupId)
            ? local
            : LocalPickupDetails(pickupId: created.pickupId);
      } else {
        details = LocalPickupDetails(
          pickupId: created.pickupId,
          requestDate: requestDate,
          requestedAt: now,
          location: location.point,
          locationAccuracyMeters: location.accuracyMeters,
        );
      }
      await AuthService.savePickupDetails(details);
      if (!ref.mounted) return _asIdResult(result);

      state = _activeState(details, events: const [], syncedAt: now);
      return _asIdResult(result);
    } finally {
      _mutating = false;
    }
  }

  /// Reports the outcome of the active pickup via `PUT /pickups/status`.
  /// [status] is a [PickupStatus] value. (Existing business rule: the
  /// resident confirms the outcome.)
  Future<ApiResult<void>> resolve(String status, {int? points}) async {
    final id = state.pickupId;
    if (!state.isActive || id == null) {
      return const ApiResult.failure('There is no active pickup to update.');
    }
    if (_mutating) {
      return const ApiResult.failure('Please wait, a request is in progress.');
    }
    _mutating = true;
    _generation++;

    try {
      final result = await _repo.updatePickupStatus(
        UpdatePickupStatusRequest(pickupId: id, status: status, points: points),
      );
      if (!ref.mounted || !result.isSuccess) return result;

      await AuthService.clearPickupId();
      if (!ref.mounted) return result;

      state = state.copyWith(
        phase: backendStatusToPhase[status] ?? PickupPhase.closed,
        resolvedAt: DateTime.now(),
        clearSyncError: true,
      );
      // Points / pickup count / last pickup date may have changed.
      ref.invalidate(userProfileProvider);
      return result;
    } finally {
      _mutating = false;
    }
  }

  ApiResult<String> _asIdResult(ApiResult<CreatedPickup> result) {
    return result.isSuccess
        ? ApiResult.success(result.data!.pickupId, statusCode: result.statusCode)
        : ApiResult.failure(result.errorMessage, statusCode: result.statusCode);
  }
}
