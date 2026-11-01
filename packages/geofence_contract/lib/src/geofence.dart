import 'geo_point.dart';

/// The geographic area associated with one scheduled pickup.
///
/// Issued by the backend, which is authoritative for it. There are no default
/// values: the radius and version must come from the backend's configuration.
class Geofence {
  /// Backend identifier of this geofence.
  final String id;

  /// Pickup the geofence belongs to.
  final String pickupId;

  final GeoPoint center;

  /// Radius in meters, as configured by the backend.
  final double radiusMeters;

  /// Configuration version. Events report the version they were evaluated
  /// against, so the backend can reject events based on an outdated geofence.
  final int version;

  Geofence({
    required this.id,
    required this.pickupId,
    required this.center,
    required this.radiusMeters,
    required this.version,
  }) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'must not be empty');
    if (pickupId.isEmpty) {
      throw ArgumentError.value(pickupId, 'pickupId', 'must not be empty');
    }
    if (!radiusMeters.isFinite || radiusMeters <= 0) {
      throw ArgumentError.value(radiusMeters, 'radiusMeters', 'must be > 0');
    }
  }
}
