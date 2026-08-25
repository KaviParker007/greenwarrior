import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/api_logger.dart';

/// Wraps an [http.Client] and logs every call that passes through it.
///
/// Because all HTTP in the app goes through [ApiClient.client], installing this
/// once covers every endpoint -- no screen or service adds logging of its own.
///
/// In profile/release builds [send] delegates straight to the inner client, so
/// there is no buffering, formatting or timing overhead outside debug.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!kDebugMode) return _inner.send(request);

    final id = ApiLogger.nextId();

    ApiLogger.request(
      id: id,
      method: request.method,
      url: request.url,
      headers: request.headers,
      // Only a finalized http.Request exposes a readable body. Reading a
      // streamed or multipart body here would consume it before it is sent.
      body: request is http.Request ? request.body : null,
    );

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _inner.send(request);

      // The body is a single-subscription stream, so it is buffered here and
      // replayed to the caller. Without this, logging it would consume it.
      final bytes = await response.stream.toBytes();
      stopwatch.stop();

      ApiLogger.response(
        id: id,
        method: request.method,
        url: request.url,
        statusCode: response.statusCode,
        elapsed: stopwatch.elapsed,
        headers: response.headers,
        body: utf8.decode(bytes, allowMalformed: true),
      );

      // Rebuilt with every field preserved so callers see an identical response.
      return http.StreamedResponse(
        Stream<List<int>>.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (error, stackTrace) {
      stopwatch.stop();
      ApiLogger.failure(
        id: id,
        method: request.method,
        url: request.url,
        error: error,
        elapsed: stopwatch.elapsed,
        stackTrace: stackTrace,
      );
      // Logging must never swallow a failure.
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
