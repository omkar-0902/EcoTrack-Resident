import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geofence_contract/geofence_contract.dart';
import 'package:geolocator/geolocator.dart';

import '../core/config/location_config.dart';

/// Why a location could not be used.
enum LocationIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,

  /// No fix within [LocationConfig.fixTimeout], or a platform error.
  unavailable,

  /// A fix was obtained but its accuracy is worse than the configured limit.
  inaccurate,
}

/// One position reading. Only used for the pickup request; never stored as a
/// history.
class LocationFix {
  final GeoPoint point;

  /// Horizontal accuracy (meters) as reported by the device, if known.
  final double? accuracyMeters;
  final DateTime capturedAt;

  const LocationFix({
    required this.point,
    required this.accuracyMeters,
    required this.capturedAt,
  });
}

class LocationOutcome {
  final LocationFix? fix;
  final LocationIssue? issue;

  const LocationOutcome.success(LocationFix this.fix) : issue = null;
  const LocationOutcome.failure(LocationIssue this.issue, {this.fix});

  bool get isSuccess => issue == null && fix != null;
}

/// User-facing text for each [LocationIssue].
String describeLocationIssue(LocationIssue issue, {double? accuracyMeters}) {
  switch (issue) {
    case LocationIssue.serviceDisabled:
      return "Location services (GPS) are turned off.";
    case LocationIssue.permissionDenied:
      return "Location permission is required to schedule a pickup.";
    case LocationIssue.permissionDeniedForever:
      return "Location permission is blocked. Enable it in Settings.";
    case LocationIssue.unavailable:
      return "Could not get your location. Please try again.";
    case LocationIssue.inaccurate:
      final acc = accuracyMeters == null ? '' : ' (±${accuracyMeters.round()} m)';
      return "Your location is not precise enough$acc. Move to an open area "
          "and try again.";
  }
}

/// Foreground location access for the resident app.
///
/// The resident app only needs the location at the moment a pickup is
/// scheduled. It never tracks the resident in the background and never
/// requests background ("all the time") permission.
abstract interface class LocationService {
  /// Checks services and permission, asking for "while using the app"
  /// permission if it has not been decided yet. Returns null when location
  /// can be used.
  Future<LocationIssue?> ensurePermission();

  /// Ensures permission, then reads one position.
  Future<LocationOutcome> getCurrentFix();

  /// Opens the system screen that resolves [issue] (location settings or
  /// app settings). Returns false if it could not be opened.
  Future<bool> openSettingsFor(LocationIssue issue);
}

class GeolocatorLocationService implements LocationService {
  final double? maxAccuracyMeters;

  const GeolocatorLocationService({this.maxAccuracyMeters});

  @override
  Future<LocationIssue?> ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationIssue.serviceDisabled;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Requests foreground permission only (the manifest declares no
        // background location permission).
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return null;
        case LocationPermission.deniedForever:
          return LocationIssue.permissionDeniedForever;
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return LocationIssue.permissionDenied;
      }
    } catch (e) {
      debugPrint('Location permission check failed: $e');
      return LocationIssue.unavailable;
    }
  }

  @override
  Future<LocationOutcome> getCurrentFix() async {
    final issue = await ensurePermission();
    if (issue != null) return LocationOutcome.failure(issue);

    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: LocationConfig.fixTimeout,
      );
      final fix = LocationFix(
        point: GeoPoint(p.latitude, p.longitude),
        accuracyMeters: p.accuracy.isFinite && p.accuracy >= 0 ? p.accuracy : null,
        capturedAt: p.timestamp,
      );
      final limit = maxAccuracyMeters;
      final acc = fix.accuracyMeters;
      if (limit != null && (acc == null || acc > limit)) {
        return LocationOutcome.failure(LocationIssue.inaccurate, fix: fix);
      }
      return LocationOutcome.success(fix);
    } catch (e) {
      debugPrint('Location lookup failed: $e');
      return const LocationOutcome.failure(LocationIssue.unavailable);
    }
  }

  @override
  Future<bool> openSettingsFor(LocationIssue issue) async {
    try {
      return issue == LocationIssue.serviceDisabled
          ? await Geolocator.openLocationSettings()
          : await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Could not open settings: $e');
      return false;
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(
    maxAccuracyMeters: LocationConfig.maxPickupAccuracyMeters,
  ),
);
