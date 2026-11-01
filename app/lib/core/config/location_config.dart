/// Location settings. Values that affect business rules are build-time
/// configuration, never hard-coded.
///
///   flutter run --dart-define=PICKUP_MAX_ACCURACY_M=50
class LocationConfig {
  LocationConfig._();

  static const String _maxAccuracyRaw =
      String.fromEnvironment('PICKUP_MAX_ACCURACY_M');

  /// If set, a pickup location fix whose reported accuracy is worse than this
  /// (meters) is refused and the resident is asked to retry. Unset by default:
  /// the acceptable accuracy must be agreed with the backend team.
  static double? get maxPickupAccuracyMeters {
    final v = double.tryParse(_maxAccuracyRaw);
    return (v != null && v > 0) ? v : null;
  }

  /// How long to wait for a GPS fix before giving up (existing app value).
  static const Duration fixTimeout = Duration(seconds: 20);
}
