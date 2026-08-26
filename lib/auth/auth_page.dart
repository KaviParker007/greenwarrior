import 'package:flutter/material.dart';

import '../pages/Qr_Scan/bin_collection.dart';
import '../pages/login.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';

/// Decides the first screen: the D2D collections screen when a session is
/// stored, login otherwise.
///
/// A stored refresh token is enough. The access token may already have expired,
/// but [ApiClient] renews it on the first 401 rather than making the user log in
/// again, and falls back to the login page if that renewal fails.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool? _hasSession;

  @override
  void initState() {
    super.initState();
    // Resolve the device id once at startup so it is ready before any scan.
    DeviceService.deviceId();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final hasSession = await AuthService.hasSession();
    if (!mounted) return;
    setState(() => _hasSession = hasSession);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSession == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _hasSession! ? const BinCollectionScreen() : const LoginPage();
  }
}
