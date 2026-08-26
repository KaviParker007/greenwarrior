import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenwarrior/auth/auth_page.dart';
import 'package:greenwarrior/pages/Qr_Scan/bin_collection.dart';
import 'package:greenwarrior/pages/d2d/d2d_dashboard_page.dart';
import 'package:greenwarrior/pages/login.dart';
import 'package:greenwarrior/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
      home: home,
      routes: {
        '/login_page': (_) => const LoginPage(),
        '/d2d_dashboard': (_) => const D2dDashboardPage(),
        '/bin_collection': (_) => const BinCollectionScreen(),
      },
    );

void main() {
  tearDown(() => ApiClient.client = http.Client());

  testWidgets('a successful login lands on the D2D collections screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.client = MockClient((request) async {
      if (request.url.path == '/drf_login/') {
        return http.Response(
          jsonEncode({
            'access': 'access-1',
            'refresh': 'refresh-1',
            'user': {'id': 1, 'username': 'collector'},
          }),
          200,
        );
      }
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(_app(const LoginPage()));
    await tester.enterText(find.byType(TextFormField).first, 'collector');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    // The card is taller than the default 800x600 test viewport.
    await tester.ensureVisible(find.text('Login'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(BinCollectionScreen), findsOneWidget);
    expect(find.byType(D2dDashboardPage), findsNothing);
  });

  testWidgets('relaunching with a stored session also lands on D2D',
      (tester) async {
    // Must match the post-login destination, otherwise restarting the app would
    // open a different screen than logging in does.
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
      'username': 'collector',
    });
    ApiClient.client = MockClient((request) async => http.Response('[]', 200));

    await tester.pumpWidget(_app(const AuthPage()));
    await tester.pumpAndSettle();

    expect(find.byType(BinCollectionScreen), findsOneWidget);
  });

  testWidgets('the dashboard is still reachable from the drawer',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
      'username': 'collector',
    });
    ApiClient.client = MockClient((request) async => http.Response('[]', 200));

    await tester.pumpWidget(_app(const BinCollectionScreen()));
    await tester.pumpAndSettle();

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();

    // The landing screen owns the highlight now.
    final d2d = tester.widget<ListTile>(
      find.ancestor(of: find.text('D2D'), matching: find.byType(ListTile)),
    );
    expect(d2d.tileColor, isNotNull);

    await tester.tap(find.text('D2D Dashboard'));
    await tester.pumpAndSettle();
    expect(find.byType(D2dDashboardPage), findsOneWidget);
  });

  testWidgets('no stored session still lands on login', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(_app(const AuthPage()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(BinCollectionScreen), findsNothing);
  });
}

