import 'package:flutter/material.dart';
import 'package:greenwarrior/auth/auth_page.dart';
import 'package:greenwarrior/pages/Qr_Scan/bin_collection.dart';
import 'package:greenwarrior/pages/d2d/d2d_dashboard_page.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:greenwarrior/theme/dark_mode.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HR2',
      theme: darkMode,
      debugShowCheckedModeBanner: false,
      home: const AuthPage(),
      routes: {
        "/login_page": (context) => const LoginPage(),
        "/d2d_dashboard": (context) => const D2dDashboardPage(),
        "/bin_collection": (context) => const BinCollectionScreen(),
      },
    );
  }
}
