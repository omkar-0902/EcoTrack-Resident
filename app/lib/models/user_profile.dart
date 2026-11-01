/// Resident profile returned by `GET /users/profile`.
///
/// Only the fields the UI already consumes are mapped. Parsing is tolerant:
/// missing or differently-typed values (e.g. `"12"` vs `12`, `null`) fall back
/// to safe defaults instead of throwing at runtime.
class UserProfile {
  final String userName;
  final int ecoPoints;
  final int totalPickups;

  /// Raw date string as sent by the backend; empty when the resident has no
  /// completed pickups yet.
  final String lastPickupDate;

  const UserProfile({
    required this.userName,
    required this.ecoPoints,
    required this.totalPickups,
    required this.lastPickupDate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userName: _asString(json['userName']),
      ecoPoints: _asInt(json['ecoPoints']),
      totalPickups: _asInt(json['totalPickups']),
      lastPickupDate: _asString(json['lastPickupDate']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _asString(Object? value) => value == null ? '' : value.toString();
}
