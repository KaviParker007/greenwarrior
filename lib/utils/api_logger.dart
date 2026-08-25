import 'package:flutter/foundation.dart';

import 'log_sanitizer.dart';

/// Formats and prints the API request/response blocks.
///
/// Emitted by [LoggingHttpClient] for every call, so no screen or service needs
/// its own logging. Silent outside debug builds.
///
/// Requests and responses are printed as separate blocks because calls overlap
/// (the dashboard fires three at once). Each pair shares a sequence number --
/// `API REQUEST #4` and `API RESPONSE #4` -- so they can be matched even when
/// interleaved.
class ApiLogger {
  const ApiLogger._();

  /// Set false to silence API logs without rebuilding.
  static bool enabled = true;

  /// Response headers are verbose; flip this on when debugging caching, CORS or
  /// content negotiation.
  static bool includeResponseHeaders = false;

  /// Bodies longer than this are truncated so one huge payload cannot bury the
  /// rest of the log.
  static int maxBodyChars = 4000;

  static int _sequence = 0;

  static bool get _active => kDebugMode && enabled;

  /// Allocates the id shared by a request and its response.
  static int nextId() => ++_sequence;

  @visibleForTesting
  static void resetSequence() => _sequence = 0;

  static void request({
    required int id,
    required String method,
    required Uri url,
    required Map<String, String> headers,
    String? body,
  }) {
    if (!_active) return;

    final buffer = StringBuffer()
      ..writeln('========== API REQUEST #$id ==========')
      ..writeln('URL: ${LogSanitizer.url(url)}')
      ..writeln('Method: ${method.toUpperCase()}')
      ..writeln('Headers: ${LogSanitizer.map(LogSanitizer.headers(headers))}')
      ..writeln(
        'Query Parameters: '
        '${LogSanitizer.map(LogSanitizer.queryParameters(url.queryParameters))}',
      )
      ..writeln('Request Body: ${_truncate(LogSanitizer.body(body))}')
      ..write('======================================');

    debugPrint(buffer.toString());
  }

  static void response({
    required int id,
    required String method,
    required Uri url,
    required int statusCode,
    required Duration elapsed,
    required Map<String, String> headers,
    required String body,
  }) {
    if (!_active) return;

    final buffer = StringBuffer()
      ..writeln('========== API RESPONSE #$id ==========')
      ..writeln('URL: ${method.toUpperCase()} ${LogSanitizer.url(url)}')
      ..writeln('Status Code: $statusCode  ${_statusLabel(statusCode)}')
      ..writeln('Response Time: ${elapsed.inMilliseconds} ms');

    if (includeResponseHeaders) {
      buffer.writeln(
        'Response Headers: ${LogSanitizer.map(LogSanitizer.headers(headers))}',
      );
    }

    buffer
      ..writeln('Response Body: ${_truncate(LogSanitizer.body(body))}')
      ..write('=======================================');

    debugPrint(buffer.toString());
  }

  /// Logs a failed call.
  ///
  /// [id] is null for failures raised outside the transport, such as the
  /// request timeout applied by the calling service.
  static void failure({
    required String method,
    required Uri url,
    required Object error,
    int? id,
    Duration? elapsed,
    StackTrace? stackTrace,
  }) {
    if (!_active) return;

    final buffer = StringBuffer()
      ..writeln('========== API ERROR #${id ?? '-'} ==========')
      ..writeln('URL: ${method.toUpperCase()} ${LogSanitizer.url(url)}')
      ..writeln('Error Type: ${error.runtimeType}')
      ..writeln('Error: $error');

    if (elapsed != null) {
      buffer.writeln('Failed After: ${elapsed.inMilliseconds} ms');
    }
    if (stackTrace != null) {
      buffer.writeln('Stack Trace:\n${_firstFrames(stackTrace)}');
    }
    buffer.write('====================================');

    debugPrint(buffer.toString());
  }

  static String _statusLabel(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return '(success)';
    if (statusCode == 401) return '(unauthorized - token refresh expected)';
    if (statusCode >= 400 && statusCode < 500) return '(client error)';
    if (statusCode >= 500) return '(server error)';
    return '';
  }

  static String _truncate(String value) {
    if (value.length <= maxBodyChars) return value;
    final omitted = value.length - maxBodyChars;
    return '${value.substring(0, maxBodyChars)}\n'
        '... [truncated $omitted more chars]';
  }

  /// Keeps the stack readable: the top frames are the useful ones.
  static String _firstFrames(StackTrace stackTrace, {int count = 6}) {
    final lines = stackTrace.toString().trim().split('\n');
    if (lines.length <= count) return lines.join('\n');
    return '${lines.take(count).join('\n')}\n... [${lines.length - count} more frames]';
  }
}
