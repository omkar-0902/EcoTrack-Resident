import 'geo_point.dart';
import 'geofence.dart';
import 'geofence_policy.dart';

/// Result of comparing one location fix with a geofence.
enum Proximity {
  /// Inside even after accounting for the fix's accuracy.
  inside,

  /// Outside even after accounting for the fix's accuracy.
  outside,

  /// The accuracy circle straddles the boundary; no decision.
  uncertain,

  /// Accuracy unknown or worse than the policy allows; not usable.
  unusable,
}

/// Accuracy-aware, side-effect-free geofence checks. A device-side result is a
/// claim for the backend to verify, never proof of arrival.
class GeofenceEvaluator {
  final GeofencePolicy policy;

  const GeofenceEvaluator(this.policy);

  Proximity classify(
    Geofence geofence,
    GeoPoint position, {
    required double? accuracyMeters,
  }) {
    if (accuracyMeters == null ||
        !accuracyMeters.isFinite ||
        accuracyMeters < 0 ||
        accuracyMeters > policy.maxAccuracyMeters) {
      return Proximity.unusable;
    }
    final distance = geofence.center.distanceTo(position);
    if (distance + accuracyMeters <= geofence.radiusMeters) {
      return Proximity.inside;
    }
    if (distance - accuracyMeters > geofence.radiusMeters) {
      return Proximity.outside;
    }
    return Proximity.uncertain;
  }
}

/// Turns a stream of [Proximity] results into enter/exit transitions. Only
/// confident results change state, so GPS jitter near the boundary does not
/// produce flapping enter/exit events.
class GeofenceTransitionDetector {
  Proximity? _confirmed;

  /// The last confident state (inside / outside), or null if none yet.
  Proximity? get state => _confirmed;

  /// Returns [Proximity.inside] on an entry, [Proximity.outside] on an exit,
  /// or null when nothing changed. The first confident reading establishes
  /// the state; it is reported only if it is "inside".
  Proximity? update(Proximity reading) {
    if (reading != Proximity.inside && reading != Proximity.outside) {
      return null;
    }
    final previous = _confirmed;
    _confirmed = reading;
    if (previous == reading) return null;
    if (previous == null && reading == Proximity.outside) return null;
    return reading;
  }
}
