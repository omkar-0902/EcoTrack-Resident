/// Thresholds that MUST be agreed with the backend. Deliberately has no
/// defaults: every value has to be supplied from configuration.
class GeofencePolicy {
  /// Fixes with a reported accuracy worse than this are not used to decide
  /// inside/outside.
  final double maxAccuracyMeters;

  /// Events older than this (relative to "now") are rejected as stale.
  final Duration maxEventAge;

  /// Events timestamped further than this in the future are rejected
  /// (device clock problems).
  final Duration maxClockSkew;

  /// Delays before each retry of a failed delivery. Its length is the maximum
  /// number of retries; after that the event is marked failed (never retried
  /// indefinitely).
  final List<Duration> retryDelays;

  GeofencePolicy({
    required this.maxAccuracyMeters,
    required this.maxEventAge,
    required this.maxClockSkew,
    required List<Duration> retryDelays,
  }) : retryDelays = List.unmodifiable(retryDelays) {
    if (!maxAccuracyMeters.isFinite || maxAccuracyMeters <= 0) {
      throw ArgumentError.value(maxAccuracyMeters, 'maxAccuracyMeters');
    }
    if (maxEventAge <= Duration.zero) {
      throw ArgumentError.value(maxEventAge, 'maxEventAge');
    }
    if (maxClockSkew < Duration.zero) {
      throw ArgumentError.value(maxClockSkew, 'maxClockSkew');
    }
    if (retryDelays.any((d) => d < Duration.zero)) {
      throw ArgumentError.value(retryDelays, 'retryDelays');
    }
  }

  /// Total delivery attempts allowed (first attempt + retries).
  int get maxAttempts => retryDelays.length + 1;
}
