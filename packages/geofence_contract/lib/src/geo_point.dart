import 'dart:math' as math;

/// A WGS-84 coordinate.
class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint(this.latitude, this.longitude) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'must be in [-90, 90]');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(longitude, 'longitude', 'must be in [-180, 180]');
    }
  }

  static const double _earthRadiusMeters = 6371008.8;

  /// Great-circle (haversine) distance in meters.
  double distanceTo(GeoPoint other) {
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLon = rad(other.longitude - longitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(a)));
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}
