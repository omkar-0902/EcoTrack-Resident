import 'package:geofence_contract/geofence_contract.dart';

/// Status values sent to `PUT /pickups/status`.
///
/// These are the exact strings the app already sends; confirm the full set
/// with the backend before adding new ones.
class PickupStatus {
  PickupStatus._();

  static const String completed = 'COMPLETED';
  static const String failed = 'FAILED';
}

/// Body for `POST /pickups`.
class CreatePickupRequest {
  /// Date in `yyyy-MM-dd` format.
  final String requestDate;
  final double latitude;
  final double longitude;

  const CreatePickupRequest({
    required this.requestDate,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'requestDate': requestDate,
        'latitude': latitude,
        'longitude': longitude,
      };
}

/// Body for `PUT /pickups/status`.
class UpdatePickupStatusRequest {
  final String pickupId;
  final String status;
  final int? points;

  const UpdatePickupStatusRequest({
    required this.pickupId,
    required this.status,
    this.points,
  });

  Map<String, dynamic> toJson() => {
        'pickupId': pickupId,
        'status': status,
        if (points != null) 'points': points,
      };
}

/// Result of `POST /pickups`.
class CreatedPickup {
  final String pickupId;

  /// True when the server refused to create a new pickup because one was
  /// already active (403) and that existing pickup was returned instead.
  final bool alreadyExisted;

  const CreatedPickup(this.pickupId, {required this.alreadyExisted});
}

/// Details of a pickup created on this device, persisted locally because the
/// backend does not return them (`/pickups/active` only returns the id).
class LocalPickupDetails {
  final String pickupId;

  /// Collection date the resident selected (date part only is meaningful).
  final DateTime? requestDate;

  /// When the server accepted the request (`POST /pickups` returned 2xx).
  final DateTime? requestedAt;

  /// Pickup location sent with the request (the resident's position when
  /// scheduling).
  final GeoPoint? location;

  /// Reported accuracy of [location] in meters, if known.
  final double? locationAccuracyMeters;

  const LocalPickupDetails({
    required this.pickupId,
    this.requestDate,
    this.requestedAt,
    this.location,
    this.locationAccuracyMeters,
  });

  /// Local storage format (not a backend contract).
  Map<String, Object?> toJson() => {
        'pickupId': pickupId,
        'requestDate': requestDate?.toIso8601String(),
        'requestedAt': requestedAt?.toIso8601String(),
        'lat': location?.latitude,
        'lng': location?.longitude,
        'accuracy': locationAccuracyMeters,
      };

  /// Tolerant: unknown or malformed values become null.
  static LocalPickupDetails? fromJson(Map<String, Object?> json) {
    final id = json['pickupId'];
    if (id is! String || id.isEmpty) return null;
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    final lat = json['lat'], lng = json['lng'], acc = json['accuracy'];
    GeoPoint? point;
    if (lat is num && lng is num) {
      try {
        point = GeoPoint(lat.toDouble(), lng.toDouble());
      } on ArgumentError {
        point = null;
      }
    }
    return LocalPickupDetails(
      pickupId: id,
      requestDate: date(json['requestDate']),
      requestedAt: date(json['requestedAt']),
      location: point,
      locationAccuracyMeters: acc is num ? acc.toDouble() : null,
    );
  }
}

/// One pickup as returned by a future "get pickup" / "history" endpoint.
///
/// PREPARED, NOT A CONTRACT: no such endpoint exists yet. Fields are limited
/// to what the app already sends or displays; map the real response onto
/// this when the endpoint is agreed.
class PickupRecord {
  final String pickupId;

  /// Backend status string, kept raw until the status enumeration is agreed.
  final String? rawStatus;
  final DateTime? requestDate;
  final GeoPoint? location;

  const PickupRecord({
    required this.pickupId,
    this.rawStatus,
    this.requestDate,
    this.location,
  });
}

/// Result of `GET /pickups/active`. The backend currently returns the active
/// pickup id as a plain-text body, or an empty body when there is none.
class ActivePickup {
  final String? pickupId;

  const ActivePickup(this.pickupId);

  bool get isActive => pickupId != null && pickupId!.isNotEmpty;
}
