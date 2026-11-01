import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_profile.dart';
import '../../../services/api_result.dart';
import '../../../services/user_service.dart';

/// Thrown by [userProfileProvider] when the profile cannot be loaded.
class ProfileLoadException implements Exception {
  final String message;
  final bool isUnauthorized;

  ProfileLoadException(ApiResult<Object?> result)
      : message = result.errorMessage,
        isUnauthorized = result.isUnauthorized;

  @override
  String toString() => message;
}

/// The signed-in resident's profile, shared by Home, Rewards and Profile so
/// the app makes one request instead of three and all tabs show the same data.
///
/// Call `ref.invalidate(userProfileProvider)` to refetch (e.g. after a pickup
/// is completed). It is auto-disposed when the home screens are removed (e.g.
/// on logout), so the next session always starts with a fresh fetch.
final userProfileProvider = FutureProvider.autoDispose<UserProfile>(
  (ref) async {
    final result = await UserService.getProfile();
    if (result.isSuccess) return result.data!;
    throw ProfileLoadException(result);
  },
  // Errors are surfaced in the UI with a manual retry instead of being
  // retried automatically (Riverpod 3 retries by default), so an expired
  // session does not cause repeated requests.
  retry: (retryCount, error) => null,
);
