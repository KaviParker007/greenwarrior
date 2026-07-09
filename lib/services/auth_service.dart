// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthService {

  /// Refresh Access Token using Refresh Token
  static Future<bool> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/drf_refresh_token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "refresh": refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final newAccessToken = data['access'];

        await prefs.setString('access_token', newAccessToken);

        print("✅ New Access Token Generated");
        return true;
      } else {
        print("❌ Refresh Token Expired");
        return false;
      }
    } catch (e) {
      print("Refresh Error: $e");
      return false;
    }
  }
}