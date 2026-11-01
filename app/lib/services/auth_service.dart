import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../core/config/api_config.dart';
import '../models/pickup.dart';
import 'api_result.dart';
import 'api_service.dart';

/// Authentication and session management.
///
/// The JWT returned by the backend is stored in secure storage and read back
/// by other services when making authenticated requests.
class AuthService {
  AuthService._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  /// Role sent when a resident registers from this app.
  static const String residentRole = 'ROLE_RESIDENT';

  // ---------------------------------------------------------------------------
  // Registration & login
  // ---------------------------------------------------------------------------

  /// `POST /public/register`
  static Future<ApiResult<void>> registerUser({
    required String userName,
    required String password,
    required String phoneNumber,
    required String address,
    String role = residentRole,
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.register,
        body: {
          'userName': userName,
          'password': password,
          'phoneNumber': phoneNumber,
          'address': address,
          'role': role,
        },
      );

      if (ApiService.isSuccess(response)) {
        return ApiResult.success(null, statusCode: response.statusCode);
      }
      if (response.statusCode == 403) {
        return ApiResult.failure(
          'Registration failed (Forbidden)',
          statusCode: response.statusCode,
        );
      }
      return ApiResult.failure(
        'Something went wrong',
        statusCode: response.statusCode,
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e.message);
    }
  }

  /// `POST /users/login`. On success the response body is the raw JWT, which
  /// is persisted and returned.
  static Future<ApiResult<String>> loginUser({
    required String userName,
    required String password,
  }) async {
    try {
      final response = await ApiService.post(
        ApiEndpoints.login,
        body: {'userName': userName, 'password': password},
      );

      if (ApiService.isSuccess(response)) {
        final token = response.body.trim();
        if (token.isEmpty) {
          return ApiResult.failure(
            'Login failed: the server returned an empty token',
            statusCode: response.statusCode,
          );
        }
        if (!await _write(_tokenKey, token)) {
          return ApiResult.failure(
            'Login succeeded but the session could not be saved on this device',
          );
        }
        return ApiResult.success(token, statusCode: response.statusCode);
      }
      return ApiResult.failure(
        'Invalid credentials',
        statusCode: response.statusCode,
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e.message);
    }
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  /// True when a stored, non-expired JWT exists.
  static Future<bool> isSessionValid() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      if (JwtDecoder.isExpired(token)) {
        await logout();
        return false;
      }
      return true;
    } catch (_) {
      // Not a decodable JWT.
      return false;
    }
  }

  static Future<String?> getToken() => _read(_tokenKey);

  /// Username from the JWT `sub` claim, if present.
  static Future<String?> getUsernameFromToken() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final sub = JwtDecoder.decode(token)['sub'];
      return sub?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    await _delete(_tokenKey);
    await clearPickupId();
  }

  // ---------------------------------------------------------------------------
  // Locally cached active pickup
  //
  // The backend's `/pickups/active` only returns the pickup id. The date the
  // resident chose, when the request was accepted and the location sent are
  // known only to the device that created it, so they are kept here as one
  // JSON record (never invented, never a location history).
  // ---------------------------------------------------------------------------

  static const _pickupDetailsKey = 'pickup_details';

  /// Keys used by earlier builds; still cleared so nothing is left behind.
  static const _legacyPickupKeys = [
    'pickup_id',
    'pickup_request_date',
    'pickup_requested_at',
  ];

  static Future<String?> getPickupId() async =>
      (await getPickupDetails())?.pickupId;

  static Future<void> savePickupDetails(LocalPickupDetails details) async {
    await _write(_pickupDetailsKey, jsonEncode(details.toJson()));
  }

  /// Locally known details of the active pickup, or null if none is cached
  /// (or the stored record is unreadable).
  static Future<LocalPickupDetails?> getPickupDetails() async {
    final raw = await _read(_pickupDetailsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? LocalPickupDetails.fromJson(decoded.cast<String, Object?>())
          : null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> clearPickupId() async {
    await _delete(_pickupDetailsKey);
    for (final key in _legacyPickupKeys) {
      await _delete(key);
    }
  }

  // ---------------------------------------------------------------------------
  // Storage helpers: secure storage can throw on some devices (e.g. corrupted
  // keystore). Treat failures as "no value" instead of crashing the app.
  // ---------------------------------------------------------------------------

  static Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Secure storage read failed for "$key": $e');
      return null;
    }
  }

  static Future<bool> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      debugPrint('Secure storage write failed for "$key": $e');
      return false;
    }
  }

  static Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Secure storage delete failed for "$key": $e');
    }
  }
}
