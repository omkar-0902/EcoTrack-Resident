import 'dart:async';
import 'dart:convert';

import 'package:app/main.dart';
import 'package:app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds an unsigned JWT whose payload has [sub] and an `exp` far in the
/// future (or in the past when [expired] is true). Good enough for
/// `jwt_decoder`, which only decodes the payload.
String fakeJwt({String sub = 'tester', bool expired = false}) {
  String enc(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now()
          .add(expired ? const Duration(days: -1) : const Duration(days: 30))
          .millisecondsSinceEpoch ~/
      1000;
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({'sub': sub, 'exp': exp})}.sig';
}

typedef Handler = http.Response Function(http.Request request);

/// In-memory stand-in for the backend. Each endpoint can be overridden per
/// test; every request is recorded in [requests].
class FakeBackend {
  final List<http.Request> requests = [];

  Handler login = (_) => http.Response(fakeJwt(), 200);
  Handler register = (_) => http.Response('', 200);
  Handler profile = (_) => http.Response(
        jsonEncode({
          'userName': 'tester',
          'ecoPoints': 40,
          'totalPickups': 3,
          'lastPickupDate': '2026-10-30',
        }),
        200,
      );
  Handler activePickup = (_) => http.Response('', 200);
  Handler createPickup = (_) => http.Response('42', 200);
  Handler pickupStatus = (_) => http.Response('', 200);

  /// When set, `GET /pickups/active` waits for this before answering. Lets a
  /// test hold a sync in flight (e.g. to race it against a status update).
  Completer<void>? activeGate;

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final path = request.url.path;
    switch ('${request.method} $path') {
      case 'POST /users/login':
        return login(request);
      case 'POST /public/register':
        return register(request);
      case 'GET /users/profile':
        return profile(request);
      case 'GET /pickups/active':
        final gate = activeGate;
        if (gate != null) await gate.future;
        return activePickup(request);
      case 'POST /pickups':
        return createPickup(request);
      case 'PUT /pickups/status':
        return pickupStatus(request);
    }
    return http.Response('not found', 404);
  });

  Iterable<http.Request> requestsTo(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == path);
}

/// Common per-test setup: fake backend, mocked secure storage, no font
/// downloads.
FakeBackend setUpFakes({String? token}) {
  GoogleFonts.config.allowRuntimeFetching = false;

  FlutterSecureStorage.setMockInitialValues({'jwt_token': ?token});

  final backend = FakeBackend();
  ApiService.client = backend.client;
  return backend;
}

/// Pumps the real app on a phone-sized surface (default 393x852 logical px,
/// a common Android/iOS size) so layout overflows surface as test failures.
///
/// [bottomInset] simulates the Android system navigation area in logical px
/// (about 24 for gesture navigation, 48 for 3-button navigation).
///
/// Note: the test font renders every glyph 1em wide (wider than real fonts),
/// so text-heavy rows are stressed more than on a real device.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  String initialRoute = '/',
  Size logicalSize = const Size(393, 852),
  double bottomInset = 0,
  List<Override> overrides = const [],
}) async {
  const dpr = 3.0;
  tester.view.physicalSize = logicalSize * dpr;
  tester.view.devicePixelRatio = dpr;
  if (bottomInset > 0) {
    final padding = FakeViewPadding(bottom: bottomInset * dpr);
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
  }
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(initialRoute: initialRoute),
    ),
  );
  return container;
}

/// Lets pending futures (mock HTTP, secure storage) complete and animations
/// finish without requiring every animation to be finite.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Simulates the Android system back button / back gesture.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
}

/// Scrolls [finder] into view if needed, then taps it.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}
