import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geofence_contract/geofence_contract.dart';

import '../core/config/api_config.dart';
import '../models/pickup.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// What the connected backend can do. Everything not backed by a verified
/// endpoint is `false`; flip a flag only when its endpoint exists and the
/// matching [HttpPickupRepository] method is implemented.
class PickupCapabilities {
  /// Retrieve one pickup by id (any status, incl. past ones).
  final bool fetchById;

  /// List the resident's past and current pickups.
  final bool history;

  /// Cancel a pending pickup.
  final bool cancel;

  /// Retrieve the backend-issued geofence for a pickup.
  final bool geofence;

  /// Retrieve verified collector/backend events (assignment, approach,
  /// arrival, collection...) for a pickup.
  final bool verifiedEvents;

  const PickupCapabilities({
    this.fetchById = false,
    this.history = false,
    this.cancel = false,
    this.geofence = false,
    this.verifiedEvents = false,
  });

  /// The backend as verified on 2026-11-01: only active / create / status.
  static const current = PickupCapabilities();
}

/// Pickup data access used by the app. The UI and state layer depend on this
/// interface only, so the backend developer can complete [HttpPickupRepository]
/// (or swap the implementation) without touching screens.
abstract interface class PickupRepository {
  PickupCapabilities get capabilities;

  // --- Backed by verified endpoints --------------------------------------

  /// `GET /pickups/active`
  Future<ApiResult<ActivePickup>> getActivePickup();

  /// `POST /pickups`
  Future<ApiResult<CreatedPickup>> createPickup(CreatePickupRequest request);

  /// `PUT /pickups/status`
  Future<ApiResult<void>> updatePickupStatus(UpdatePickupStatusRequest request);

  // --- Prepared integration points (no backend contract yet) -------------

  Future<ApiResult<PickupRecord>> getPickup(String pickupId);

  Future<ApiResult<List<PickupRecord>>> getPickupHistory();

  Future<ApiResult<void>> cancelPickup(String pickupId);

  /// Backend-issued geofence for [pickupId] (authoritative configuration).
  Future<ApiResult<Geofence>> getGeofence(String pickupId);

  /// Events the backend has VERIFIED for [pickupId]. The resident app only
  /// displays these; it never produces collector events.
  Future<ApiResult<List<GeofenceEvent>>> getVerifiedEvents(String pickupId);
}

class HttpPickupRepository implements PickupRepository {
  const HttpPickupRepository();

  @override
  PickupCapabilities get capabilities => PickupCapabilities.current;

  static const _notSignedIn =
      ApiResult<Never>.failure('You are not signed in', statusCode: 401);

  @override
  Future<ApiResult<ActivePickup>> getActivePickup() async {
    final token = await AuthService.getToken();
    if (token == null) return _notSignedIn;

    try {
      final response =
          await ApiService.get(ApiEndpoints.activePickup, token: token);

      if (!ApiService.isSuccess(response)) {
        return ApiResult.failure(
          'Could not check your pickup status',
          statusCode: response.statusCode,
        );
      }
      // Current contract: plain-text pickup id, or an empty body for none.
      final id = response.body.trim();
      return ApiResult.success(
        ActivePickup(id.isEmpty ? null : id),
        statusCode: response.statusCode,
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e.message);
    }
  }

  @override
  Future<ApiResult<CreatedPickup>> createPickup(
    CreatePickupRequest request,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) return _notSignedIn;

    try {
      final response = await ApiService.post(
        ApiEndpoints.pickups,
        token: token,
        body: request.toJson(),
      );

      if (ApiService.isSuccess(response)) {
        final id = response.body.trim();
        if (id.isEmpty) {
          return ApiResult.failure(
            'The server did not return a pickup id',
            statusCode: response.statusCode,
          );
        }
        return ApiResult.success(
          CreatedPickup(id, alreadyExisted: false),
          statusCode: response.statusCode,
        );
      }

      // The backend answers 403 when the resident already has an active
      // pickup; return that one, flagged, so the newly entered details are
      // not attributed to an earlier request.
      if (response.statusCode == 403) {
        final active = await getActivePickup();
        if (active.isSuccess && active.data!.isActive) {
          return ApiResult.success(
            CreatedPickup(active.data!.pickupId!, alreadyExisted: true),
            statusCode: 200,
          );
        }
      }

      return ApiResult.failure(
        'Could not schedule the pickup',
        statusCode: response.statusCode,
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e.message);
    }
  }

  @override
  Future<ApiResult<void>> updatePickupStatus(
    UpdatePickupStatusRequest request,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) return _notSignedIn;

    try {
      final response = await ApiService.put(
        ApiEndpoints.pickupStatus,
        token: token,
        body: request.toJson(),
      );

      if (ApiService.isSuccess(response)) {
        return ApiResult.success(null, statusCode: response.statusCode);
      }
      return ApiResult.failure(
        'Could not update the pickup status',
        statusCode: response.statusCode,
      );
    } on ApiException catch (e) {
      return ApiResult.failure(e.message);
    }
  }

  // No endpoints exist for these yet. They send nothing and say so.

  @override
  Future<ApiResult<PickupRecord>> getPickup(String pickupId) async =>
      const ApiResult.notSupported('Fetching a pickup by id');

  @override
  Future<ApiResult<List<PickupRecord>>> getPickupHistory() async =>
      const ApiResult.notSupported('Pickup history');

  @override
  Future<ApiResult<void>> cancelPickup(String pickupId) async =>
      const ApiResult.notSupported('Cancelling a pickup');

  @override
  Future<ApiResult<Geofence>> getGeofence(String pickupId) async =>
      const ApiResult.notSupported('Pickup geofence');

  @override
  Future<ApiResult<List<GeofenceEvent>>> getVerifiedEvents(
    String pickupId,
  ) async =>
      const ApiResult.notSupported('Verified pickup events');
}

final pickupRepositoryProvider = Provider<PickupRepository>(
  (ref) => const HttpPickupRepository(),
);
