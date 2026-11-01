/// Outcome of a service call, returned to the UI instead of raw HTTP
/// responses or untyped maps.
class ApiResult<T> {
  final T? data;
  final String? message;
  final int? statusCode;
  final bool isSuccess;

  /// True when the operation has no backend endpoint yet (see
  /// `PickupCapabilities`). No request was sent.
  final bool isNotSupported;

  const ApiResult._({
    required this.isSuccess,
    this.data,
    this.message,
    this.statusCode,
    this.isNotSupported = false,
  });

  const ApiResult.success(T data, {int? statusCode})
      : this._(isSuccess: true, data: data, statusCode: statusCode);

  const ApiResult.failure(String message, {int? statusCode})
      : this._(isSuccess: false, message: message, statusCode: statusCode);

  /// The backend does not provide this capability yet. Never a fake success.
  const ApiResult.notSupported(String capability)
      : this._(
          isSuccess: false,
          message: '$capability is not supported by the backend yet',
          isNotSupported: true,
        );

  /// True when the server rejected the request's credentials (HTTP 401).
  bool get isUnauthorized => statusCode == 401;

  /// User-facing error text; always non-null for failures.
  String get errorMessage => message ?? 'Something went wrong';
}
