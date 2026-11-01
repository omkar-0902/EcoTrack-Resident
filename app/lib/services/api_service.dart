import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';

/// Thrown when a request could not reach the server or did not complete
/// (no connectivity, DNS failure, timeout). HTTP error status codes are NOT
/// thrown; callers inspect [http.Response.statusCode] for those.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

/// Low-level HTTP wrapper. All requests go through here so base URL,
/// headers, auth and timeouts are applied consistently.
class ApiService {
  ApiService._();

  /// HTTP client used for every request. Replaceable in tests
  /// (e.g. with `MockClient` from `package:http/testing.dart`).
  static http.Client client = http.Client();

  static Uri buildUri(String endpoint) =>
      Uri.parse('${ApiConfig.baseUrl}$endpoint');

  static Map<String, String> headers({String? token}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<http.Response> get(String endpoint, {String? token}) {
    return _send(() => client.get(buildUri(endpoint), headers: headers(token: token)));
  }

  static Future<http.Response> post(
    String endpoint, {
    Object? body,
    String? token,
  }) {
    return _send(
      () => client.post(
        buildUri(endpoint),
        headers: headers(token: token),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  static Future<http.Response> put(
    String endpoint, {
    Object? body,
    String? token,
  }) {
    return _send(
      () => client.put(
        buildUri(endpoint),
        headers: headers(token: token),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        'Unable to reach the server. Check your internet connection.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Unable to reach the server. Check your internet connection.',
      );
    } on HandshakeException {
      throw const ApiException('Secure connection to the server failed.');
    }
  }

  static bool isSuccess(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;
}
