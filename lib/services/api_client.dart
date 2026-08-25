import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../utils/api_logger.dart';
import 'api_exception.dart';
import 'auth_service.dart';
import 'logging_http_client.dart';

/// Single entry point for every authenticated API call.
///
/// Responsibilities kept here so no screen has to repeat them:
///  * attaches `Authorization: Bearer <access_token>`
///  * on `401`, refreshes the access token once and replays the request
///  * converts transport failures and error bodies into [ApiException]
///  * logs requests and responses in debug builds
class ApiClient {
  const ApiClient._();

  static const Duration _timeout = Duration(seconds: 25);

  /// Shared transport for every call in the app, including the auth calls in
  /// [AuthService]. Swappable so tests can drive the refresh-and-retry path
  /// without real network access.
  ///
  /// Wrapped in [LoggingHttpClient] so every request and response is logged
  /// from one place; the wrapper is a pass-through outside debug builds.
  static http.Client client = LoggingHttpClient(http.Client());

  static Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) {
    return _send('GET', path, query: query, authenticated: authenticated);
  }

  static Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _send('POST', path, body: body, authenticated: authenticated);
  }

  static Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
    bool allowRefresh = true,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );

    try {
      final response =
          await _dispatch(method, uri, body, authenticated).timeout(_timeout);

      // Access token expired: refresh once, then replay the original request.
      // `allowRefresh` prevents an unbounded retry loop.
      if (response.statusCode == 401 && authenticated && allowRefresh) {
        final refreshed = await AuthService.refreshAccessToken();
        if (!refreshed) {
          throw const SessionExpiredException();
        }
        return _send(
          method,
          path,
          query: query,
          body: body,
          authenticated: authenticated,
          allowRefresh: false,
        );
      }

      return _decode(response);
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      // Raised by .timeout() above, outside the transport, so the logging
      // client never sees it -- record it here instead.
      ApiLogger.failure(method: method, url: uri, error: error);
      throw const ApiException(
        'The request timed out. Please check your connection and try again.',
      );
    } on SocketException {
      // Already logged by LoggingHttpClient.
      throw const ApiException(
        'No internet connection. Please check your network and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Could not reach the server. Please try again.',
      );
    } on FormatException catch (error) {
      // Thrown while decoding a 2xx body, after the response was logged.
      ApiLogger.failure(method: method, url: uri, error: error);
      throw const ApiException(
        'The server returned an unexpected response.',
      );
    }
  }

  static Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Object? body,
    bool authenticated,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await AuthService.accessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (method == 'POST') {
      return client.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    }
    return client.get(uri, headers: headers);
  }

  static dynamic _decode(http.Response response) {
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    if (status == 401) {
      throw const SessionExpiredException();
    }

    throw ApiException(
      friendlyMessage(status, response.body),
      statusCode: status,
    );
  }

  /// Prefers the API's own message and otherwise falls back to friendly text,
  /// so a raw server error or HTML error page never reaches the user.
  static String friendlyMessage(int status, String body) {
    final apiMessage = _extractMessage(body);
    if (apiMessage != null) return apiMessage;

    switch (status) {
      case 400:
        return 'The request was invalid. Please check your input and try again.';
      case 403:
        return 'You do not have permission to view this information.';
      case 404:
        return 'The requested information could not be found.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'The server is temporarily unavailable. Please try again shortly.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  static String? _extractMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['detail', 'message', 'error']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
        // DRF field errors, e.g. {"username": ["This field is required."]}
        for (final value in decoded.values) {
          if (value is List && value.isNotEmpty && value.first is String) {
            final first = (value.first as String).trim();
            if (first.isNotEmpty) return first;
          }
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
      }
      if (decoded is List && decoded.isNotEmpty && decoded.first is String) {
        final first = (decoded.first as String).trim();
        if (first.isNotEmpty) return first;
      }
    } on FormatException {
      // Not JSON (e.g. an HTML error page) -- fall back to the status message.
      return null;
    }
    return null;
  }
}
