import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_theme.dart';
import 'features/splash/presentation/splash_view.dart';
import 'features/auth/presentation/login_view.dart';
import 'features/auth/presentation/registration_view.dart';

import 'features/main/presentation/main_scaffold.dart';
import 'features/schedule/presentation/schedule_view.dart';

import 'features/onboarding/presentation/onboarding_view.dart';
import 'features/onboarding/presentation/location_permission_view.dart';

import 'features/dashboard/presentation/notifications_view.dart';
import 'features/tracking/presentation/tracking_view.dart';
import 'shared/widgets/theme_transition_wrapper.dart';
import 'core/theme_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

/// All named routes in the app.
final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const SplashView(),
  '/onboarding': (context) => const OnboardingView(),
  '/location-permission': (context) => const LocationPermissionView(),
  '/login': (context) => const LoginView(),
  '/register': (context) => const RegistrationView(),
  '/home': (context) => const MainScaffold(),
  '/schedule': (context) => const ScheduleView(),
  '/notifications': (context) => const NotificationsView(),
  // Argument: the pickup id (String) to track.
  '/track': (context) => const TrackingView(),
};

class MyApp extends ConsumerWidget {
  /// Route shown on launch. Defaults to the splash screen; overridable for
  /// tests.
  final String initialRoute;

  const MyApp({super.key, this.initialRoute = '/'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Eco Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        return ThemeTransitionWrapper(child: child!);
      },
      initialRoute: initialRoute,
      // Start with exactly the initial route. Flutter's default would also
      // push '/' (the splash) underneath any other initial route, and the
      // splash's delayed redirect would then replace the visible screen.
      onGenerateInitialRoutes: (name) => [
        MaterialPageRoute(
          settings: RouteSettings(name: name),
          builder: appRoutes[name] ?? appRoutes['/']!,
        ),
      ],
      // An unknown route name falls back to the splash screen, which routes
      // to home or onboarding based on the session, instead of crashing or
      // leaving a blank screen.
      onUnknownRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (context) => const SplashView(),
      ),
      routes: appRoutes,
    );
  }
}
