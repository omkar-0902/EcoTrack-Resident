import 'dart:convert';

import 'package:app/features/auth/presentation/login_view.dart';
import 'package:app/features/auth/presentation/registration_view.dart';
import 'package:app/features/dashboard/presentation/dashboard_view.dart';
import 'package:app/features/dashboard/presentation/notifications_view.dart';
import 'package:app/features/main/data/navigation_provider.dart';
import 'package:app/features/main/presentation/main_scaffold.dart';
import 'package:app/features/onboarding/presentation/location_permission_view.dart';
import 'package:app/features/onboarding/presentation/onboarding_view.dart';
import 'package:app/features/schedule/data/pickup_provider.dart';
import 'package:app/features/schedule/presentation/schedule_view.dart';
import 'package:app/features/tracking/presentation/tracking_view.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/shared/widgets/animated_theme_toggler.dart';
import 'package:app/shared/widgets/pill_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/test_harness.dart';

/// Visible (on-stage) instances only: IndexedStack keeps every tab built.
Finder onStage(Finder finder) => find.descendant(
      of: find.byType(Navigator),
      matching: finder,
      skipOffstage: true,
    );

void main() {
  group('Launch flow', () {
    testWidgets('splash goes to onboarding when there is no session',
        (tester) async {
      setUpFakes();
      await pumpApp(tester);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);

      expect(find.byType(OnboardingView), findsOneWidget);
    });

    testWidgets('splash goes straight to home with a valid session',
        (tester) async {
      setUpFakes(token: fakeJwt(sub: 'alice'));
      await pumpApp(tester);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);

      expect(find.byType(MainScaffold), findsOneWidget);
      expect(find.text('ALICE'), findsOneWidget);
    });

    testWidgets('onboarding Skip -> location -> Maybe later -> login',
        (tester) async {
      setUpFakes();
      await pumpApp(tester, initialRoute: '/onboarding');
      await settle(tester);

      await tapOn(tester, find.text('SKIP'));
      await settle(tester);
      expect(find.byType(LocationPermissionView), findsOneWidget);

      await tapOn(tester, find.text('MAYBE LATER'));
      await settle(tester);
      expect(find.byType(LoginView), findsOneWidget);
    });
  });

  group('Auth screens', () {
    testWidgets('Create account opens registration; app-bar back returns to login',
        (tester) async {
      setUpFakes();
      await pumpApp(tester, initialRoute: '/login');
      await settle(tester);

      await tapOn(tester, find.text('CREATE ACCOUNT'));
      await settle(tester);
      expect(find.byType(RegistrationView), findsOneWidget);

      await tapOn(tester, find.byIcon(Icons.arrow_back_ios_new));
      await settle(tester);
      expect(find.byType(RegistrationView), findsNothing);
      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('Android system back on registration returns to login',
        (tester) async {
      setUpFakes();
      await pumpApp(tester, initialRoute: '/login');
      await settle(tester);
      await tapOn(tester, find.text('CREATE ACCOUNT'));
      await settle(tester);

      await systemBack(tester);
      expect(find.byType(RegistrationView), findsNothing);
      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('registration back button never leaves a blank screen',
        (tester) async {
      setUpFakes();
      await pumpApp(tester, initialRoute: '/register');
      await settle(tester);

      await tapOn(tester, find.byIcon(Icons.arrow_back_ios_new));
      await settle(tester);
      expect(find.byType(LoginView), findsOneWidget);
    });

    testWidgets('registration validates input before calling the API',
        (tester) async {
      final backend = setUpFakes();
      await pumpApp(tester, initialRoute: '/register');
      await settle(tester);

      await tapOn(tester, find.text('INITIALIZE ACCOUNT'));
      await settle(tester);
      expect(find.text('Please fill in all fields'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('successful registration returns to login', (tester) async {
      final backend = setUpFakes();
      await pumpApp(tester, initialRoute: '/login');
      await settle(tester);
      await tapOn(tester, find.text('CREATE ACCOUNT'));
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'bob');
      await tester.enterText(fields.at(1), '9876543210');
      await tester.enterText(fields.at(2), 'Goa');
      await tester.enterText(fields.at(3), 'secret');
      await tapOn(tester, find.text('INITIALIZE ACCOUNT'));
      await settle(tester);

      expect(backend.requestsTo('POST', '/public/register'), hasLength(1));
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(RegistrationView), findsNothing);
    });

    testWidgets('login validates empty fields', (tester) async {
      final backend = setUpFakes();
      await pumpApp(tester, initialRoute: '/login');
      await settle(tester);

      await tapOn(tester, find.text('ACCESS SYSTEM'));
      await settle(tester);
      expect(find.text('Please enter your username and password'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('login network failure shows a message and stays on login',
        (tester) async {
      final backend = setUpFakes();
      backend.login = (_) => throw http.ClientException('offline');
      await pumpApp(tester, initialRoute: '/login');
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'alice');
      await tester.enterText(fields.at(1), 'pw');
      await tapOn(tester, find.text('ACCESS SYSTEM'));
      await settle(tester);

      expect(find.textContaining('Unable to reach the server'), findsOneWidget);
      expect(find.byType(LoginView), findsOneWidget);
      // Button is usable again (loading state cleared).
      expect(find.text('ACCESS SYSTEM'), findsOneWidget);
    });

    testWidgets('login success opens home; back does not return to login',
        (tester) async {
      setUpFakes();
      await pumpApp(tester, initialRoute: '/login');
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'alice');
      await tester.enterText(fields.at(1), 'pw');
      await tapOn(tester, find.text('ACCESS SYSTEM'));
      await settle(tester);

      expect(find.byType(MainScaffold), findsOneWidget);
      expect(await AuthService.getToken(), isNotNull);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });
  });

  group('Home navigation', () {
    Future<void> openHome(WidgetTester tester) async {
      await pumpApp(tester, initialRoute: '/home');
      await settle(tester);
      expect(find.byType(DashboardView), findsOneWidget);
    }

    testWidgets('dashboard bell opens notifications; back arrow returns home',
        (tester) async {
      setUpFakes(token: fakeJwt());
      await openHome(tester);

      await tapOn(tester, onStage(find.byIcon(Icons.notifications_outlined)));
      await settle(tester);
      expect(find.byType(NotificationsView), findsOneWidget);

      await tapOn(tester, find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.byType(NotificationsView), findsNothing);
      expect(onStage(find.byType(DashboardView)), findsOneWidget);
    });

    testWidgets('system back from notifications returns home', (tester) async {
      setUpFakes(token: fakeJwt());
      await openHome(tester);

      await tapOn(tester, onStage(find.byIcon(Icons.notifications_outlined)));
      await settle(tester);
      await systemBack(tester);

      expect(find.byType(NotificationsView), findsNothing);
      expect(onStage(find.byType(DashboardView)), findsOneWidget);
    });

    testWidgets('Schedule Pickup screen back button returns home',
        (tester) async {
      setUpFakes(token: fakeJwt());
      await openHome(tester);

      await tapOn(tester, find.text('SCHEDULE PICKUP'));
      await settle(tester);
      expect(onStage(find.text('Schedule a Pickup')), findsOneWidget);

      await tapOn(tester, find.byType(BackButton));
      await settle(tester);
      expect(onStage(find.text('Schedule a Pickup')), findsNothing);
      expect(onStage(find.byType(DashboardView)), findsOneWidget);
    });

    testWidgets(
        'with an active pickup, Home shows the real status and tracking back works',
        (tester) async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('55', 200);
      await openHome(tester);

      // Synced from the backend on load; no hard-coded "Collector is on the way".
      expect(find.text('Collector is on the way'), findsNothing);
      expect(onStage(find.text('Request Confirmed')), findsOneWidget);
      // The bottom navigation stays visible during an active pickup.
      expect(find.byType(PillNavigationBar), findsOneWidget);

      final trackButton = find.widgetWithText(ElevatedButton, 'TRACK PICKUP');
      await tapOn(tester, trackButton);
      await settle(tester);
      expect(find.byType(TrackingView), findsOneWidget);

      await tapOn(tester, find.byType(BackButton));
      await settle(tester);
      expect(find.byType(TrackingView), findsNothing);
      expect(onStage(find.byType(DashboardView)), findsOneWidget);

      await tapOn(tester, trackButton);
      await settle(tester);
      await systemBack(tester);
      expect(find.byType(TrackingView), findsNothing);
      expect(onStage(find.byType(DashboardView)), findsOneWidget);
    });

    testWidgets('PICKED UP reports the stored pickup id and clears the state',
        (tester) async {
      final backend = setUpFakes(token: fakeJwt());
      backend.activePickup = (_) => http.Response('55', 200);
      final container = await pumpApp(tester, initialRoute: '/home');
      await settle(tester);

      // Requests tab shows the confirmation view for the active pickup.
      container.read(navigationProvider.notifier).state = 1;
      await settle(tester);
      backend.activePickup = (_) => http.Response('', 200);
      await tapOn(tester, onStage(find.text('PICKED UP')));
      await settle(tester);

      final put = backend.requestsTo('PUT', '/pickups/status').single;
      expect(jsonDecode(put.body),
          {'pickupId': '55', 'status': 'COMPLETED', 'points': 10});
      expect(container.read(pickupActiveProvider), isFalse);
      expect(onStage(find.text('Schedule a Pickup')), findsOneWidget);
      // Profile is refetched so points update.
      expect(backend.requestsTo('GET', '/users/profile').length, greaterThan(1));
    });

    testWidgets('app-bar bell on the Rewards tab opens notifications',
        (tester) async {
      setUpFakes(token: fakeJwt());
      final container = await pumpApp(tester, initialRoute: '/home');
      await settle(tester);
      container.read(navigationProvider.notifier).state = 2;
      await settle(tester);

      await tapOn(tester, onStage(find.byIcon(Icons.notifications_none_rounded)));
      await settle(tester);
      expect(find.byType(NotificationsView), findsOneWidget);

      await tapOn(tester, find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.byType(NotificationsView), findsNothing);
    });

    testWidgets('logo cycles tabs and system back on a tab returns to Home',
        (tester) async {
      setUpFakes(token: fakeJwt());
      final container = await pumpApp(tester, initialRoute: '/home');
      await settle(tester);

      await tapOn(tester, find.byType(ClipOval).last);
      await settle(tester);
      expect(container.read(navigationProvider), 1);

      await systemBack(tester);
      expect(container.read(navigationProvider), 0);
      expect(find.byType(MainScaffold), findsOneWidget);
    });

    testWidgets('logout clears the session and the back stack', (tester) async {
      setUpFakes(token: fakeJwt());
      final container = await pumpApp(tester, initialRoute: '/home');
      await settle(tester);
      container.read(navigationProvider.notifier).state = 3;
      await settle(tester);

      await tapOn(tester, onStage(find.text('LOGOUT')));
      await settle(tester);

      expect(find.byType(LoginView), findsOneWidget);
      expect(await AuthService.getToken(), isNull);
      expect(container.read(navigationProvider), 0);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
    });

    testWidgets('theme toggle animates without duplicate-GlobalKey errors',
        (tester) async {
      setUpFakes(token: fakeJwt());
      final container = await pumpApp(tester, initialRoute: '/home');
      await settle(tester);
      container.read(navigationProvider.notifier).state = 3;
      await settle(tester);

      final rawImagesBefore = find.byType(RawImage).evaluate().length;
      await tapOn(tester, onStage(find.byType(AnimatedThemeToggler)));
      await tester.pump(const Duration(milliseconds: 300));
      // Mid-transition: the old-theme snapshot overlay is on screen.
      expect(find.byType(RawImage).evaluate().length, rawImagesBefore + 1);
      await tester.pump(const Duration(milliseconds: 800));
      await settle(tester);
      // Transition finished: overlay removed.
      expect(find.byType(RawImage).evaluate().length, rawImagesBefore);

      // Exactly one Navigator: the app subtree is not duplicated.
      expect(find.byType(Navigator), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Navigation still works after the transition.
      await tapOn(tester, onStage(find.byIcon(Icons.notifications_none)));
      await settle(tester);
      expect(find.byType(NotificationsView), findsOneWidget);
      await tapOn(tester, find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.byType(NotificationsView), findsNothing);
    });
  });

  group('Dashboard data states', () {
    testWidgets('server error shows Retry, which recovers', (tester) async {
      final backend = setUpFakes(token: fakeJwt());
      backend.profile = (_) => http.Response('error', 500);
      await pumpApp(tester, initialRoute: '/home');
      await settle(tester);

      expect(find.text('RETRY'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      backend.profile = (_) => http.Response(
            jsonEncode({'userName': 'tester', 'ecoPoints': 7}),
            200,
          );
      await tapOn(tester, find.text('RETRY'));
      await settle(tester);
      expect(find.text('RETRY'), findsNothing);
      expect(find.text('7 pts earned'), findsOneWidget);
      expect(find.text('No completed pickups yet'), findsOneWidget);
    });

    testWidgets('401 from the server signs out to login', (tester) async {
      final backend = setUpFakes(token: fakeJwt());
      backend.profile = (_) => http.Response('', 401);
      await pumpApp(tester, initialRoute: '/home');
      await settle(tester);

      expect(find.byType(LoginView), findsOneWidget);
      expect(await AuthService.getToken(), isNull);
    });
  });

  testWidgets('notifications opened as the only route: back is a safe no-op',
      (tester) async {
    setUpFakes();
    await pumpApp(tester, initialRoute: '/notifications');
    await settle(tester);

    await tapOn(tester, find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.byType(NotificationsView), findsOneWidget);
  });

  testWidgets('unknown route falls back to splash instead of crashing',
      (tester) async {
    setUpFakes();
    await pumpApp(tester, initialRoute: '/does-not-exist');
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(find.byType(OnboardingView), findsOneWidget);
  });

  testWidgets('ScheduleView is reachable from the Requests tab', (tester) async {
    setUpFakes(token: fakeJwt());
    final container = await pumpApp(tester, initialRoute: '/home');
    await settle(tester);
    container.read(navigationProvider.notifier).state = 1;
    await settle(tester);
    expect(onStage(find.byType(ScheduleView)), findsOneWidget);
  });
}
