/// Shared geofencing contract for EcoConnect (resident) and EcoDispatch
/// (collector).
///
/// The backend is authoritative for geofence configuration, assignments,
/// verified arrival, collection and closure. Everything here helps devices
/// detect and report events consistently; nothing here decides a pickup's
/// status.
library;

export 'src/event_outbox.dart';
export 'src/geo_point.dart';
export 'src/geofence.dart';
export 'src/geofence_evaluator.dart';
export 'src/geofence_event.dart';
export 'src/geofence_policy.dart';
