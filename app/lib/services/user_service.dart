import 'dart:convert';

import '../core/config/api_config.dart';
import '../models/user_profile.dart';
import 'api_result.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Resident profile data.
class UserService {
  UserService._();

  /// `GET /users/profile` (authenticated).
  static Future<ApiResult<UserProfile>> getProfile() async {
    final token = await AuthService.getToken();
    if (token == null) {
      return const ApiResult.failure('You are not signed in', statusCode: 401);
    }

    try {
      final response = await ApiService.get(ApiEndpoints.profile, token: token);

      if (!ApiService.isSuccess(response)) {
        return ApiResult.failure(
          'Could not load your profile',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return ApiResult.failure(
          'Unexpected profile response from server',
          statusCode: response.statusCode,
        );
      }
      return ApiResult.success(
        UserProfile.fromJson(decoded),
        statusCode: response.statusCode,
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e.message);
    } on FormatException {
      return const ApiResult.failure('Unexpected profile response from server');
    }
  }
}
