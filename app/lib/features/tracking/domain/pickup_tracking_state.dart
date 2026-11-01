import 'package:geofence_contract/geofence_contract.dart';

/// Where the resident's pickup is, as far as the app can actually know.
///
/// Derived ONLY from:
///  * `POST /pickups` returning an id            -> [active]
///  * `GET /pickups/active` returning that id    -> [active]
///  * `PUT /pickups/status` COMPLETED/FAILED 2xx  -> [completed] / [notCollected]
///  * `GET /pickups/active` no longer returning it -> [closed] (outcome unknown)
///
/// Collector progress (assignment, approach, arrival, collection) is NOT a
/// phase: it is shown from [PickupTrackingState.verifiedEvents], which only
/// the backend can supply. There is one state machine, not two.
enum PickupPhase {
  /// No pickup known to the app.
  none,

  /// The server lists the pickup as active (awaiting collection).
  active,

  /// The resident reported PICKED UP and the server accepted `COMPLETED`.
  completed,

  /// The resident reported NOT PICKED UP and the server accepted `FAILED`.
  notCollected,

  /// The server stopped listing the pickup as active, but this device did not
  /// report its outcome, so whether it was completed is unknown.
  closed,
}

class PickupTrackingState {
  final PickupPhase phase;

  /// Server-issued pickup id. Null when [phase] is [PickupPhase.none].
  final String? pickupId;

  /// Collection date the resident selected. Only known if the pickup was
  /// created on this device; null otherwise (the backend does not return it).
  final DateTime? requestDate;

  /// When the server accepted the request. Only known if created on this device.
  final DateTime? requestedAt;

  /// Location sent with the pickup request. Only known on the creating device.
  final GeoPoint? pickupLocation;

  /// Reported accuracy of [pickupLocation] in meters, if known.
  final double? pickupLocationAccuracyMeters;

  /// Events the BACKEND verified for this pickup (collector assignment,
  /// approach, arrival, collection...). Empty until the backend provides an
  /// endpoint for them; never produced by this app.
  final List<GeofenceEvent> verifiedEvents;

  /// Whether the connected backend can report collector progress at all
  /// (see `PickupCapabilities.verifiedEvents`). When false, those timeline
  /// stages are shown as "not reported" rather than "upcoming".
  final bool collectorEventsSupported;

  /// When the outcome was reported (completed / not collected) or when the
  /// app noticed the server had closed the pickup.
  final DateTime? resolvedAt;

  /// Last time `GET /pickups/active` succeeded.
  final DateTime? lastSyncedAt;

  /// A sync request is in flight.
  final bool isSyncing;

  /// Message from the last failed sync. The rest of the state is the last
  /// known good state and is kept as-is.
  final String? syncError;

  const PickupTrackingState({
    this.phase = PickupPhase.none,
    this.pickupId,
    this.requestDate,
    this.requestedAt,
    this.pickupLocation,
    this.pickupLocationAccuracyMeters,
    this.verifiedEvents = const [],
    this.collectorEventsSupported = false,
    this.resolvedAt,
    this.lastSyncedAt,
    this.isSyncing = false,
    this.syncError,
  });

  bool get isActive => phase == PickupPhase.active;

  /// True if this state describes the pickup with [id].
  bool describes(String? id) => id != null && pickupId == id;

  PickupTrackingState copyWith({
    PickupPhase? phase,
    List<GeofenceEvent>? verifiedEvents,
    DateTime? resolvedAt,
    DateTime? lastSyncedAt,
    bool? isSyncing,
    String? syncError,
    bool clearSyncError = false,
  }) {
    return PickupTrackingState(
      phase: phase ?? this.phase,
      pickupId: pickupId,
      requestDate: requestDate,
      requestedAt: requestedAt,
      pickupLocation: pickupLocation,
      pickupLocationAccuracyMeters: pickupLocationAccuracyMeters,
      verifiedEvents: verifiedEvents ?? this.verifiedEvents,
      collectorEventsSupported: collectorEventsSupported,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isSyncing: isSyncing ?? this.isSyncing,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
    );
  }
}
