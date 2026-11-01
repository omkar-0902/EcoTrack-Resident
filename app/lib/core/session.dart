import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/main/data/navigation_provider.dart';
import '../features/tracking/data/pickup_tracking_controller.dart';
import '../services/auth_service.dart';

bool _signingOut = false;

/// Clears the stored session and per-user in-memory state, then returns to
/// the login screen with an empty back stack.
///
/// Safe to call more than once concurrently (e.g. a 401 arriving while the
/// user taps Logout); only the first call navigates.
///
/// The profile provider is auto-disposed once the home screens are removed,
/// so it does not need to be reset here.
Future<void> signOut(BuildContext context) async {
  if (_signingOut) return;
  _signingOut = true;
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);

    await AuthService.logout();

    navigator.pushNamedAndRemoveUntil('/login', (route) => false);

    // Reset after navigating so the outgoing home screen does not react.
    container.invalidate(navigationProvider);
    container.invalidate(pickupTrackingProvider);
  } finally {
    _signingOut = false;
  }
}
