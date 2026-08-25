import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:greenwarrior/services/api_client.dart';
import 'package:greenwarrior/services/api_exception.dart';
import 'package:greenwarrior/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every request so tests can assert on headers and ordering.
class _Recorder {
  final List<http.BaseRequest> requests = [];

  MockClient client(
    Future<http.Response> Function(http.Request request, int callIndex) handler,
  ) {
    return MockClient((request) async {
      final index = requests.length;
      requests.add(request);
      return handler(request, index);
    });
  }

  List<String> get paths => requests.map((r) => r.url.path).toList();
}

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  late _Recorder recorder;

  setUp(() {
    recorder = _Recorder();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ApiClient.client = http.Client();
  });

  group('login', () {
    test('stores tokens and user details on success', () async {
      ApiClient.client = recorder.client(
        (request, _) async => _json({
          'access': 'access-1',
          'refresh': 'refresh-1',
          'user': {
            'id': 7,
            'username': 'collector',
            'employee_name': 'Asha K',
            'project': 'PRJ-1',
            'zone': 'Z-1',
            'ward': 'W-1',
          },
        }),
      );

      final session = await AuthService.login(
        username: 'collector',
        password: 'secret',
      );

      expect(session.id, 7);
      expect(session.displayName, 'Asha K');
      expect(await AuthService.accessToken(), 'access-1');
      expect(await AuthService.refreshToken(), 'refresh-1');
      expect(await AuthService.hasSession(), isTrue);

      // The raw password must never be persisted.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('password'), isNull);
    });

    test('maps 400 to a missing-credentials message', () async {
      ApiClient.client = recorder.client(
        (request, _) async => _json({'detail': 'required'}, status: 400),
      );

      await expectLater(
        AuthService.login(username: '', password: ''),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', contains('username')),
        ),
      );
    });

    test('maps 401 to invalid credentials', () async {
      ApiClient.client = recorder.client(
        (request, _) async => _json({'detail': 'No active account'}, status: 401),
      );

      await expectLater(
        AuthService.login(username: 'a', password: 'b'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Invalid username or password.',
          ),
        ),
      );
      // Nothing is stored after a failed login.
      expect(await AuthService.hasSession(), isFalse);
    });

    test('maps 403 to a deactivated-account message', () async {
      ApiClient.client = recorder.client(
        (request, _) async => _json({'detail': 'inactive'}, status: 403),
      );

      await expectLater(
        AuthService.login(username: 'a', password: 'b'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('deactivated'),
          ),
        ),
      );
    });

    test('surfaces a friendly message for a 500 HTML error page', () async {
      ApiClient.client = recorder.client(
        (request, _) async => http.Response('<html>Server Error</html>', 500),
      );

      await expectLater(
        AuthService.login(username: 'a', password: 'b'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('temporarily unavailable'),
          ),
        ),
      );
    });
  });

  group('automatic token refresh', () {
    test('refreshes once on 401 and replays the request', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'stale',
        'refresh_token': 'refresh-1',
      });

      ApiClient.client = recorder.client((request, index) async {
        // 1st: protected call with the stale token -> 401
        if (index == 0) return _json({'detail': 'expired'}, status: 401);
        // 2nd: the refresh exchange
        if (index == 1) return _json({'access': 'fresh'});
        // 3rd: the replayed original request
        return _json([
          {'id': 1, 'ward_code': 'W-1'},
        ]);
      });

      final data = await ApiClient.get('/d2d/drf_list_queried_collections/');

      expect(data, isA<List<dynamic>>());
      expect(recorder.paths, [
        '/d2d/drf_list_queried_collections/',
        '/drf_refresh_token/',
        '/d2d/drf_list_queried_collections/',
      ]);

      // The replay must carry the new token, not the stale one.
      expect(
        recorder.requests[0].headers['Authorization'],
        'Bearer stale',
      );
      expect(
        recorder.requests[2].headers['Authorization'],
        'Bearer fresh',
      );
      expect(await AuthService.accessToken(), 'fresh');
    });

    test('throws SessionExpired when the refresh itself fails', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'stale',
        'refresh_token': 'dead',
      });

      ApiClient.client = recorder.client((request, index) async {
        if (index == 0) return _json({'detail': 'expired'}, status: 401);
        return _json({'detail': 'token blacklisted'}, status: 401);
      });

      await expectLater(
        ApiClient.get('/d2d/drf_collection_by_project/'),
        throwsA(isA<SessionExpiredException>()),
      );
    });

    test('does not retry more than once', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'stale',
        'refresh_token': 'refresh-1',
      });

      ApiClient.client = recorder.client((request, index) async {
        if (index == 1) return _json({'access': 'fresh'});
        // Every protected call keeps returning 401.
        return _json({'detail': 'expired'}, status: 401);
      });

      await expectLater(
        ApiClient.get('/d2d/drf_collection_by_zone/'),
        throwsA(isA<SessionExpiredException>()),
      );

      // Original + refresh + one replay, then it gives up.
      expect(recorder.requests, hasLength(3));
    });

    test('concurrent 401s share a single refresh call', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'stale',
        'refresh_token': 'refresh-1',
      });

      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/drf_refresh_token/') {
          return _json({'access': 'fresh'});
        }
        final auth = request.headers['Authorization'];
        if (auth == 'Bearer stale') {
          return _json({'detail': 'expired'}, status: 401);
        }
        return _json(<Map<String, dynamic>>[]);
      });

      var refreshCalls = 0;
      ApiClient.client = MockClient((request) async {
        if (request.url.path == '/drf_refresh_token/') {
          refreshCalls++;
          return _json({'access': 'fresh'});
        }
        final auth = request.headers['Authorization'];
        if (auth == 'Bearer stale') {
          return _json({'detail': 'expired'}, status: 401);
        }
        return _json(<Map<String, dynamic>>[]);
      });

      await Future.wait([
        ApiClient.get('/d2d/drf_collection_by_project/'),
        ApiClient.get('/d2d/drf_collection_by_zone/'),
        ApiClient.get('/d2d/drf_collection_by_ward/'),
      ]);

      expect(refreshCalls, 1);
    });
  });

  group('logout', () {
    test('blacklists the refresh token and clears the session', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'access-1',
        'refresh_token': 'refresh-1',
        'username': 'collector',
        'deviceId': 'device-abc',
      });

      ApiClient.client = recorder.client((request, _) async => _json({}));

      await AuthService.logout();

      expect(recorder.paths, ['/drf_logout/']);
      final sent = jsonDecode((recorder.requests.first as http.Request).body);
      expect(sent, {'refresh': 'refresh-1'});

      expect(await AuthService.hasSession(), isFalse);
      expect(await AuthService.accessToken(), isNull);
      expect(await AuthService.currentUsername(), isNull);

      // The device id is a property of the device, not the session.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('deviceId'), 'device-abc');
    });

    test('still clears the session when the token is already blacklisted',
        () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'access-1',
        'refresh_token': 'refresh-1',
      });

      ApiClient.client = recorder.client(
        (request, _) async =>
            _json({'detail': 'Token is blacklisted'}, status: 400),
      );

      await AuthService.logout();

      expect(await AuthService.hasSession(), isFalse);
    });

    test('still clears the session when the network is down', () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'access-1',
        'refresh_token': 'refresh-1',
      });

      ApiClient.client = MockClient(
        (request) async => throw http.ClientException('offline'),
      );

      await AuthService.logout();

      expect(await AuthService.hasSession(), isFalse);
    });
  });

  group('network failures surface friendly messages', () {
    test('transport failure', () async {
      SharedPreferences.setMockInitialValues({'access_token': 'a'});
      ApiClient.client = MockClient(
        (request) async => throw http.ClientException('offline'),
      );

      await expectLater(
        ApiClient.get('/d2d/drf_collection_by_project/'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Could not reach the server'),
          ),
        ),
      );
    });

    test('malformed body', () async {
      SharedPreferences.setMockInitialValues({'access_token': 'a'});
      ApiClient.client = MockClient(
        (request) async => http.Response('not json', 200),
      );

      await expectLater(
        ApiClient.get('/d2d/drf_collection_by_project/'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('unexpected response'),
          ),
        ),
      );
    });
  });
}
