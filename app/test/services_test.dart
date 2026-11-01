import 'dart:convert';

import 'package:app/core/config/api_config.dart';
import 'package:app/models/pickup.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/auth_service.dart';
import 'package:app/repositories/pickup_repository.dart';
import 'package:app/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    test('login sends credentials as JSON and stores the trimmed token',
        () async {
      final backend = setUpFakes();
      final jwt = fakeJwt(sub: 'alice');
      backend.login = (_) => http.Response('  $jwt\n', 200);

      final result =
          await AuthService.loginUser(userName: 'alice', password: 'pw');

      expect(result.isSuccess, isTrue);
      expect(result.data, jwt);
      expect(await AuthService.getToken(), jwt);
      expect(await AuthService.getUsernameFromToken(), 'alice');
      expect(await AuthService.isSessionValid(), isTrue);

      final req = backend.requestsTo('POST', ApiEndpoints.login).single;
      expect(req.url.toString(), '${ApiConfig.baseUrl}/users/login');
      expect(req.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(req.body), {'userName': 'alice', 'password': 'pw'});
    });

    test('login with wrong credentials fails without storing a token',
        () async {
      final backend = setUpFakes();
      backend.login = (_) => http.Response('Unauthorized', 401);

      final result =
          await AuthService.loginUser(userName: 'alice', password: 'bad');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'Invalid credentials');
      expect(await AuthService.getToken(), isNull);
    });

    test('network failure becomes a failure result instead of throwing',
        () async {
      setUpFakes();
      ApiService.client = MockClient(
        (_) async => throw http.ClientException('connection refused'),
      );

      final result =
          await AuthService.loginUser(userName: 'alice', password: 'pw');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Unable to reach the server'));
    });

    test('expired token is not a valid session and is cleared', () async {
      setUpFakes(token: fakeJwt(expired: true));

      expect(await AuthService.isSessionValid(), isFalse);
      expect(await AuthService.getToken(), isNull);
    });

    test('register accepts any 2xx and sends the resident role', () async {
      final backend = setUpFakes();
      backend.register = (_) => http.Response('', 201);

      final result = await AuthService.registerUser(
        userName: 'bob',
        password: 'pw',
        phoneNumber: '9876543210',
        address: 'Goa',
      );

      expect(result.isSuccess, isTrue);
      final body = jsonDecode(
        backend.requestsTo('POST', ApiEndpoints.register).single.body,
      );
      expect(body['role'], 'ROLE_RESIDENT');
      expect(body['phoneNumber'], '9876543210');
    });
  });

  group('UserService', () {
    test('sends the bearer token and parses the profile', () async {
      final token = fakeJwt();
      final backend = setUpFakes(token: token);

      final result = await UserService.getProfile();

      expect(result.isSuccess, isTrue);
      expect(result.data!.ecoPoints, 40);
      expect(
        backend.requestsTo('GET', ApiEndpoints.profile).single.headers['Authorization'],
        'Bearer $token',
      );
    });

    test('profile parsing tolerates missing and string-typed fields', () {
      final profile = UserProfile.fromJson({'ecoPoints': '12', 'totalPickups': null});
      expect(profile.ecoPoints, 12);
      expect(profile.totalPickups, 0);
      expect(profile.userName, '');
      expect(profile.lastPickupDate, '');
    });

    test('non-JSON profile body is a failure, not a crash', () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.profile = (_) => http.Response('<html>oops</html>', 200);

      final result = await UserService.getProfile();
      expect(result.isSuccess, isFalse);
    });

    test('no stored token is reported as unauthorized without a request',
        () async {
      final backend = setUpFakes();

      final result = await UserService.getProfile();
      expect(result.isUnauthorized, isTrue);
      expect(backend.requests, isEmpty);
    });
  });

  group('PickupService', () {
    test('active pickup: empty body means none, text body is the id',
        () async {
      final backend = setUpFakes(token: fakeJwt());

      expect((await const HttpPickupRepository().getActivePickup()).data!.isActive, isFalse);

      backend.activePickup = (_) => http.Response('77', 200);
      final active = await const HttpPickupRepository().getActivePickup();
      expect(active.data!.isActive, isTrue);
      expect(active.data!.pickupId, '77');
    });

    test('create pickup posts date and coordinates', () async {
      final backend = setUpFakes(token: fakeJwt());

      final result = await const HttpPickupRepository().createPickup(
        const CreatePickupRequest(
          requestDate: '2026-11-02',
          latitude: 15.5,
          longitude: 73.8,
        ),
      );

      expect(result.data!.pickupId, '42');
      expect(result.data!.alreadyExisted, isFalse);
      expect(
        jsonDecode(backend.requestsTo('POST', ApiEndpoints.pickups).single.body),
        {'requestDate': '2026-11-02', 'latitude': 15.5, 'longitude': 73.8},
      );
    });

    test('create pickup 403 falls back to the existing active pickup',
        () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.createPickup = (_) => http.Response('', 403);
      backend.activePickup = (_) => http.Response('9', 200);

      final result = await const HttpPickupRepository().createPickup(
        const CreatePickupRequest(requestDate: 'd', latitude: 0, longitude: 0),
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.pickupId, '9');
      // Flagged so the app does not attach the newly entered date to it.
      expect(result.data!.alreadyExisted, isTrue);
    });

    test('status update omits points unless provided', () async {
      final backend = setUpFakes(token: fakeJwt());

      await const HttpPickupRepository().updatePickupStatus(
        const UpdatePickupStatusRequest(pickupId: '1', status: PickupStatus.failed),
      );
      await const HttpPickupRepository().updatePickupStatus(
        const UpdatePickupStatusRequest(
          pickupId: '1',
          status: PickupStatus.completed,
          points: 10,
        ),
      );

      final bodies = backend
          .requestsTo('PUT', ApiEndpoints.pickupStatus)
          .map((r) => jsonDecode(r.body))
          .toList();
      expect(bodies[0], {'pickupId': '1', 'status': 'FAILED'});
      expect(bodies[1], {'pickupId': '1', 'status': 'COMPLETED', 'points': 10});
    });

    test('server error on status update is a failure result', () async {
      final backend = setUpFakes(token: fakeJwt());
      backend.pickupStatus = (_) => http.Response('boom', 500);

      final result = await const HttpPickupRepository().updatePickupStatus(
        const UpdatePickupStatusRequest(pickupId: '1', status: PickupStatus.failed),
      );
      expect(result.isSuccess, isFalse);
      expect(result.statusCode, 500);
    });
  });
}
