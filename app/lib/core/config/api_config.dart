/// Central configuration for the backend API.
///
/// The base URL can be overridden at build/run time without code changes:
///
///   flutter run --dart-define=API_BASE_URL=https://my-backend.example.com
///   flutter build apk --dart-define=API_BASE_URL=https://my-backend.example.com
///
/// Every endpoint path the app calls is listed in [ApiEndpoints] so the
/// backend contract lives in one place instead of being scattered across UI
/// and service files.
///
/// Per-environment values can be kept in a file (see `config/*.example.json`):
///
///   flutter run --dart-define-from-file=config/dev.json
///   flutter build apk --dart-define-from-file=config/prod.json
///
/// No credentials or secrets belong here: authentication uses the JWT the
/// backend issues at login.
class ApiConfig {
  ApiConfig._();

  /// `dev` or `prod` (informational; e.g. for logging / diagnostics).
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ecotrack-rm92.onrender.com',
  );

  /// Maximum time to wait for a single HTTP request before failing.
  /// The default backend is hosted on Render, whose free tier can take
  /// a while to wake up, so this is intentionally generous.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// How often the tracking screen re-checks `GET /pickups/active` while it
  /// is open and the app is in the foreground. The backend has no push /
  /// WebSocket / SSE channel, so polling is the only way to see changes.
  static const Duration trackingPollInterval = Duration(seconds: 30);
}

/// Endpoint paths currently used by the app (relative to [ApiConfig.baseUrl]).
class ApiEndpoints {
  ApiEndpoints._();

  static const String register = '/public/register';
  static const String login = '/users/login';
  static const String profile = '/users/profile';
  static const String pickups = '/pickups';
  static const String activePickup = '/pickups/active';
  static const String pickupStatus = '/pickups/status';
}
