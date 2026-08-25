import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/user_session.dart';
import '../utils/api_logger.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Authentication and JWT lifecycle.
///
/// Uses [ApiClient.client] for transport but bypasses [ApiClient]'s request
/// pipeline on purpose: that pipeline calls [refreshAccessToken] on a 401, so
/// routing the refresh back through it would recurse.
///
/// Token lifetimes (server side): access 12 hours, refresh 2 days, refresh not
/// rotated, so the stored refresh token stays valid across refreshes.
class AuthService {
  const AuthService._();

  static const Duration _timeout = Duration(seconds: 25);

  // Storage keys. Kept stable so existing installs keep their session.
  static const String _keyAccess = 'access_token';
  static const String _keyRefresh = 'refresh_token';
  static const String _keyUserId = 'userid';
  static const String _keyUsername = 'username';
  static const String _keyEmployeeName = 'employee_name';
  static const String _keyProject = 'project';
  static const String _keyZone = 'zone';
  static const String _keyWard = 'ward';
  /// No longer written: the drawer highlight is passed in by each screen.
  /// Still cleared on logout so upgraded installs shed the dead key.
  static const String _keyMenu = 'menu';

  /// Guards against several concurrent 401s each firing their own refresh.
  static Future<bool>? _inFlightRefresh;

  // ---------------------------------------------------------------- login ---

  /// Authenticates and persists the session.
  ///
  /// Throws [ApiException] with a user-facing message for the documented
  /// failures: 400 (missing field), 401 (bad credentials), 403 (deactivated).
  static Future<UserSession> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/drf_login/');

    try {
      final response = await ApiClient.client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(_timeout);

      switch (response.statusCode) {
        case 200:
          return _persistSession(response.body);
        case 400:
          throw const ApiException(
            'Please enter both your username and password.',
            statusCode: 400,
          );
        case 401:
          throw const ApiException(
            'Invalid username or password.',
            statusCode: 401,
          );
        case 403:
          throw const ApiException(
            'Your account has been deactivated. Please contact your administrator.',
            statusCode: 403,
          );
        default:
          throw ApiException(
            ApiClient.friendlyMessage(response.statusCode, response.body),
            statusCode: response.statusCode,
          );
      }
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      // Raised outside the transport, so log it here; everything else is
      // already logged by LoggingHttpClient.
      ApiLogger.failure(method: 'POST', url: uri, error: error);
      throw const ApiException(
        'The request timed out. Please check your connection and try again.',
      );
    } on SocketException {
      throw const ApiException(
        'No internet connection. Please check your network and try again.',
      );
    } on http.ClientException {
      throw const ApiException('Could not reach the server. Please try again.');
    } on FormatException catch (error) {
      ApiLogger.failure(method: 'POST', url: uri, error: error);
      throw const ApiException('The server returned an unexpected response.');
    }
  }

  static Future<UserSession> _persistSession(String responseBody) async {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('The server returned an unexpected response.');
    }

    final access = decoded['access'];
    final refresh = decoded['refresh'];
    final rawUser = decoded['user'];

    if (access is! String ||
        access.isEmpty ||
        rawUser is! Map<String, dynamic>) {
      throw const ApiException(
        'The server returned an incomplete login response.',
      );
    }

    final session = UserSession.fromJson(rawUser);
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyAccess, access);
    if (refresh is String && refresh.isNotEmpty) {
      await prefs.setString(_keyRefresh, refresh);
    }
    await prefs.setInt(_keyUserId, session.id);
    await prefs.setString(_keyUsername, session.username);
    await prefs.setString(_keyEmployeeName, session.employeeName ?? '');
    await prefs.setString(_keyProject, session.project ?? '');
    await prefs.setString(_keyZone, session.zone ?? '');
    await prefs.setString(_keyWard, session.ward ?? '');

    return session;
  }

  // --------------------------------------------------------------- logout ---

  /// Blacklists the refresh token server side, then clears the local session.
  ///
  /// The local session is cleared even when the call fails: an invalid or
  /// already-blacklisted token still means the user is signing out, so they are
  /// never left stuck in a signed-in state.
  static Future<void> logout() async {
    final token = await refreshToken();

    if (token != null) {
      final uri = Uri.parse('${AppConfig.apiUrl}/drf_logout/');
      try {
        final access = await accessToken();

        // The response is not inspected: the outcome does not change the local
        // sign-out below. LoggingHttpClient records it either way.
        await ApiClient.client
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json; charset=UTF-8',
                'Accept': 'application/json',
                if (access != null) 'Authorization': 'Bearer $access',
              },
              body: jsonEncode({'refresh': token}),
            )
            .timeout(_timeout);
      } catch (error) {
        // Network down, or the token was already blacklisted/invalid. Either
        // way the local sign-out below still has to happen.
        AppLogger.error('Logout call failed; clearing session anyway', error);
      }
    }

    await clearSession();
  }

  // -------------------------------------------------------------- refresh ---

  /// Exchanges the refresh token for a new access token.
  ///
  /// Returns false when the session cannot be recovered. Concurrent callers
  /// share a single in-flight request so a burst of 401s triggers one refresh.
  static Future<bool> refreshAccessToken() {
    return _inFlightRefresh ??=
        _performRefresh().whenComplete(() => _inFlightRefresh = null);
  }

  static Future<bool> _performRefresh() async {
    final token = await refreshToken();
    if (token == null) return false;

    final uri = Uri.parse('${AppConfig.apiUrl}/drf_refresh_token/');
    try {
      final response = await ApiClient.client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh': token}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return false;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;

      final access = decoded['access'];
      if (access is! String || access.isEmpty) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccess, access);

      // The refresh token is not rotated server side, but honour a new one if
      // the API ever starts returning it.
      final rotated = decoded['refresh'];
      if (rotated is String && rotated.isNotEmpty) {
        await prefs.setString(_keyRefresh, rotated);
      }
      return true;
    } catch (error) {
      AppLogger.error('Token refresh failed', error);
      return false;
    }
  }

  // -------------------------------------------------------------- session ---

  static Future<String?> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return _nonEmpty(prefs.getString(_keyAccess));
  }

  static Future<String?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return _nonEmpty(prefs.getString(_keyRefresh));
  }

  static Future<String?> currentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return _nonEmpty(prefs.getString(_keyUsername));
  }

  /// Label for the drawer header: employee name when known, else username.
  static Future<String?> currentDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return _nonEmpty(prefs.getString(_keyEmployeeName)) ??
        _nonEmpty(prefs.getString(_keyUsername));
  }

  /// A session exists when a refresh token is stored: the access token may have
  /// expired, but it can be renewed without asking the user to log in again.
  static Future<bool> hasSession() async {
    return (await refreshToken()) != null;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      _keyAccess,
      _keyRefresh,
      _keyUserId,
      _keyUsername,
      _keyEmployeeName,
      _keyProject,
      _keyZone,
      _keyWard,
      _keyMenu,
      // Legacy key from before the session became token-based.
      'password',
    ]) {
      await prefs.remove(key);
    }
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
