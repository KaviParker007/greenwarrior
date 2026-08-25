import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenwarrior/services/api_client.dart';
import 'package:greenwarrior/services/auth_service.dart';
import 'package:greenwarrior/services/logging_http_client.dart';
import 'package:greenwarrior/utils/api_logger.dart';
import 'package:greenwarrior/utils/log_sanitizer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures everything the loggers emit so tests can assert on the output.
class _LogCapture {
  final List<String> lines = [];
  late DebugPrintCallback _original;

  void start() {
    _original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
  }

  void stop() => debugPrint = _original;

  String get text => lines.join('\n');
}

/// Real secrets that must never appear in a log.
const _accessToken = 'eyJhbGciOiJIUzI1NiJ9.ACCESS-SECRET-VALUE';
const _refreshToken = 'eyJhbGciOiJIUzI1NiJ9.REFRESH-SECRET-VALUE';
const _password = 'SuperSecret123!';

void main() {
  late _LogCapture capture;

  setUp(() {
    capture = _LogCapture()..start();
    ApiLogger.resetSequence();
    ApiLogger.includeResponseHeaders = false;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    capture.stop();
    ApiClient.client = http.Client();
    ApiLogger.includeResponseHeaders = false;
  });

  /// Installs a logging client over a stubbed transport.
  void stub(Future<http.Response> Function(http.Request request) handler) {
    ApiClient.client = LoggingHttpClient(MockClient(handler));
  }

  group('log block contents', () {
    test('records every required field for a request and its response',
        () async {
      SharedPreferences.setMockInitialValues({'access_token': _accessToken});

      stub((request) async => http.Response(
            jsonEncode([
              {'id': 1, 'project_code': 'PRJ-A'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          ));

      await ApiClient.get(
        '/d2d/drf_collection_by_project/',
        query: {'collected_date': '2026-08-24'},
      );

      final log = capture.text;

      // Request block
      expect(log, contains('========== API REQUEST #1 =========='));
      expect(log, contains('URL: https://hr-square.com/d2d/drf_collection_by_project/'));
      expect(log, contains('Method: GET'));
      expect(log, contains('Headers:'));
      expect(log, contains('Query Parameters:'));
      expect(log, contains('collected_date'));
      expect(log, contains('2026-08-24'));
      expect(log, contains('Request Body: (none)'));

      // Response block
      expect(log, contains('========== API RESPONSE #1 =========='));
      expect(log, contains('Status Code: 200'));
      expect(log, contains('Response Time:'));
      expect(log, contains(RegExp(r'Response Time: \d+ ms')));
      expect(log, contains('Response Body:'));
      expect(log, contains('PRJ-A'));
    });

    test('logs the POST payload and pretty-prints JSON', () async {
      stub((request) async => http.Response('{"ok":true}', 201));

      await ApiClient.post(
        '/d2d/drf_collect_house/',
        body: {'house_id': 12, 'device_id': 'abc123'},
      );

      final log = capture.text;
      expect(log, contains('Method: POST'));
      expect(log, contains('"house_id": 12'));
      expect(log, contains('"device_id": "abc123"'));
      expect(log, contains('Status Code: 201'));
    });

    test('pairs a request with its response by id even when interleaved',
        () async {
      SharedPreferences.setMockInitialValues({'access_token': _accessToken});
      stub((request) async {
        // Zone resolves after ward, forcing the blocks to interleave.
        if (request.url.path.contains('zone')) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
        return http.Response('[]', 200);
      });

      await Future.wait([
        ApiClient.get('/d2d/drf_collection_by_zone/'),
        ApiClient.get('/d2d/drf_collection_by_ward/'),
      ]);

      final log = capture.text;
      for (final id in [1, 2]) {
        expect(log, contains('API REQUEST #$id'));
        expect(log, contains('API RESPONSE #$id'));
      }
    });

    test('includes response headers only when asked', () async {
      stub((request) async =>
          http.Response('{}', 200, headers: {'x-trace-id': 'trace-42'}));

      await ApiClient.get('/d2d/drf_collection_by_ward/');
      expect(capture.text, isNot(contains('trace-42')));

      capture.lines.clear();
      ApiLogger.includeResponseHeaders = true;
      await ApiClient.get('/d2d/drf_collection_by_ward/');
      expect(capture.text, contains('Response Headers:'));
      expect(capture.text, contains('trace-42'));
    });

    test('annotates a 401 so the refresh flow is easy to follow', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
      });

      var calls = 0;
      stub((request) async {
        calls++;
        if (calls == 1) return http.Response('{"detail":"expired"}', 401);
        if (request.url.path == '/drf_refresh_token/') {
          return http.Response('{"access":"new-token-value"}', 200);
        }
        return http.Response('[]', 200);
      });

      await ApiClient.get('/d2d/drf_collection_by_project/');

      final log = capture.text;
      expect(log, contains('Status Code: 401'));
      expect(log, contains('token refresh expected'));
      // The refresh and the replay are both logged.
      expect(log, contains('/drf_refresh_token/'));
      expect(log, contains('API REQUEST #3'));
    });
  });

  group('secrets are never logged', () {
    test('masks the Authorization header but keeps the scheme visible',
        () async {
      SharedPreferences.setMockInitialValues({'access_token': _accessToken});
      stub((request) async => http.Response('[]', 200));

      await ApiClient.get('/d2d/drf_collection_by_project/');

      final log = capture.text;
      expect(log, isNot(contains(_accessToken)));
      expect(log, isNot(contains('ACCESS-SECRET-VALUE')));
      // The scheme still shows, which is what you need when debugging a 401.
      expect(log, contains('Bearer ${LogSanitizer.redacted}'));
    });

    test('masks the password in a login request body', () async {
      stub((request) async => http.Response(
            jsonEncode({
              'access': _accessToken,
              'refresh': _refreshToken,
              'user': {'id': 1, 'username': 'collector'},
            }),
            200,
          ));

      await AuthService.login(username: 'collector', password: _password);

      final log = capture.text;
      expect(log, isNot(contains(_password)));
      expect(log, contains('"password": "${LogSanitizer.redacted}"'));
      // Non-sensitive fields stay readable.
      expect(log, contains('"username": "collector"'));
    });

    test('masks the JWTs in a login response body', () async {
      stub((request) async => http.Response(
            jsonEncode({
              'access': _accessToken,
              'refresh': _refreshToken,
              'user': {'id': 1, 'username': 'collector'},
            }),
            200,
          ));

      await AuthService.login(username: 'collector', password: _password);

      final log = capture.text;
      expect(log, isNot(contains(_accessToken)));
      expect(log, isNot(contains(_refreshToken)));
      expect(log, isNot(contains('SECRET-VALUE')));
      expect(log, contains('"access": "${LogSanitizer.redacted}"'));
      expect(log, contains('"refresh": "${LogSanitizer.redacted}"'));
      // The rest of the payload is still there for debugging.
      expect(log, contains('"id": 1'));
    });

    test('masks the refresh token sent to logout and to the refresh endpoint',
        () async {
      SharedPreferences.setMockInitialValues({
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
      });
      stub((request) async => http.Response('{}', 200));

      await AuthService.refreshAccessToken();
      await AuthService.logout();

      final log = capture.text;
      expect(log, isNot(contains(_refreshToken)));
      expect(log, isNot(contains(_accessToken)));
      expect(log, contains('"refresh": "${LogSanitizer.redacted}"'));
    });

    test('masks a token that arrives in a query parameter', () async {
      stub((request) async => http.Response('[]', 200));

      await ApiClient.get(
        '/d2d/drf_collection_by_project/',
        query: {'collected_date': '2026-08-24', 'api_key': 'KEY-SECRET'},
        authenticated: false,
      );

      final log = capture.text;
      expect(log, isNot(contains('KEY-SECRET')));
      // Masked in the URL line as well as the parameter block.
      expect(log, isNot(contains('api_key=KEY-SECRET')));
      expect(log, contains('2026-08-24'));
    });

    test('masks nested and list-nested credentials', () {
      final masked = LogSanitizer.body(jsonEncode({
        'outer': {
          'access_token': 'nested-secret',
          'items': [
            {'password': 'list-secret', 'name': 'keep-me'},
          ],
        },
      }));

      expect(masked, isNot(contains('nested-secret')));
      expect(masked, isNot(contains('list-secret')));
      expect(masked, contains('keep-me'));
    });
  });

  group('error logging', () {
    test('logs a transport failure with type and duration', () async {
      ApiClient.client = LoggingHttpClient(
        MockClient((request) async => throw http.ClientException('offline')),
      );

      await expectLater(
        ApiClient.get('/d2d/drf_collection_by_project/'),
        throwsA(anything),
      );

      final log = capture.text;
      expect(log, contains('========== API ERROR #1 =========='));
      expect(log, contains('Error Type: ClientException'));
      expect(log, contains('offline'));
      expect(log, contains(RegExp(r'Failed After: \d+ ms')));
      expect(log, contains('Stack Trace:'));
    });

    test('logs a non-2xx body so server errors are debuggable', () async {
      stub((request) async =>
          http.Response('{"detail":"Something broke"}', 500));

      await expectLater(
        ApiClient.get('/d2d/drf_collection_by_project/'),
        throwsA(anything),
      );

      final log = capture.text;
      expect(log, contains('Status Code: 500'));
      expect(log, contains('(server error)'));
      expect(log, contains('Something broke'));
    });

    test('leaves a non-JSON error page readable', () async {
      stub((request) async => http.Response('<html>Bad Gateway</html>', 502));

      await expectLater(
        ApiClient.get('/d2d/drf_collection_by_project/'),
        throwsA(anything),
      );

      expect(capture.text, contains('Bad Gateway'));
    });
  });

  group('behaviour is unchanged by logging', () {
    test('the caller still receives the exact response', () async {
      final payload = [
        {'id': 1, 'ward_code': 'W-1', 'total_collections': 4},
        {'id': 2, 'ward_code': 'W-2', 'total_collections': 0},
      ];
      stub((request) async => http.Response(jsonEncode(payload), 200));

      final result = await ApiClient.get('/d2d/drf_collection_by_ward/');

      // Buffering the stream for logging must not alter the decoded body.
      expect(result, payload);
    });

    test('a large body is truncated instead of flooding the console', () async {
      final big = List.generate(4000, (i) => {'id': i, 'ward_code': 'W-$i'});
      stub((request) async => http.Response(jsonEncode(big), 200));

      final result = await ApiClient.get('/d2d/drf_collection_by_ward/');

      // The caller still gets everything; only the log is trimmed.
      expect(result, hasLength(4000));
      expect(capture.text, contains('truncated'));
    });

    test('logging can be switched off entirely', () async {
      stub((request) async => http.Response('[]', 200));

      ApiLogger.enabled = false;
      addTearDown(() => ApiLogger.enabled = true);

      await ApiClient.get('/d2d/drf_collection_by_project/');

      expect(capture.text, isNot(contains('API REQUEST')));
    });
  });
}
