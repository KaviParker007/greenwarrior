import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenwarrior/components/drawer_page.dart';
import 'package:greenwarrior/pages/Qr_Scan/bin_collection.dart';
import 'package:greenwarrior/pages/d2d/d2d_dashboard_page.dart';
import 'package:greenwarrior/services/api_client.dart';
import 'package:greenwarrior/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the drawer in isolation with [active] as the current screen.
Future<void> _pumpDrawer(WidgetTester tester, DrawerMenu active) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        drawer: AppDrawer(activeMenu: active),
        body: const SizedBox.shrink(),
      ),
      routes: {
        '/d2d_dashboard': (_) => const Scaffold(body: Text('dashboard route')),
        '/bin_collection': (_) => const Scaffold(body: Text('collections route')),
        '/login_page': (_) => const Scaffold(body: Text('login')),
      },
    ),
  );
  await _openDrawer(tester);
}

Future<void> _openDrawer(WidgetTester tester) async {
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await tester.pumpAndSettle();
}

/// The ListTile behind a drawer label.
ListTile _tile(WidgetTester tester, String label) {
  return tester.widget<ListTile>(
    find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
  );
}

bool _isHighlighted(WidgetTester tester, String label) =>
    _tile(tester, label).tileColor != null;

/// Serves the dashboard and scan endpoints so both screens can render.
MockClient _api() {
  return MockClient((request) async {
    if (request.url.path == '/d2d/drf_collection_by_project/') {
      return http.Response('[]', 200);
    }
    return http.Response('[]', 200);
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'username': 'collector',
      'employee_name': 'Asha K',
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
    });
  });

  tearDown(() {
    ApiClient.client = http.Client();
  });

  group('menu highlighting', () {
    testWidgets('highlights D2D Dashboard and nothing else when it is active',
        (tester) async {
      await _pumpDrawer(tester, DrawerMenu.dashboard);

      expect(_isHighlighted(tester, 'D2D Dashboard'), isTrue);
      expect(_isHighlighted(tester, 'D2D'), isFalse);
    });

    testWidgets('highlights D2D and nothing else when it is active',
        (tester) async {
      await _pumpDrawer(tester, DrawerMenu.collections);

      // The reported bug: D2D Dashboard used to stay highlighted here.
      expect(_isHighlighted(tester, 'D2D'), isTrue);
      expect(_isHighlighted(tester, 'D2D Dashboard'), isFalse);
    });

    testWidgets('never highlights more than one item', (tester) async {
      for (final active in DrawerMenu.values) {
        await _pumpDrawer(tester, active);

        final highlighted = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .where((tile) => tile.tileColor != null)
            .length;
        expect(highlighted, 1, reason: 'exactly one tile highlighted for $active');
      }
    });

    testWidgets('ignores a stale persisted menu value', (tester) async {
      // The highlight used to be driven by this preference. Installs upgrading
      // from that version still have it set, and it must no longer influence
      // anything -- otherwise D2D Dashboard would stay lit on the D2D screen.
      SharedPreferences.setMockInitialValues({
        'username': 'collector',
        'menu': 'd2d_dashboard',
      });

      await _pumpDrawer(tester, DrawerMenu.collections);

      expect(_isHighlighted(tester, 'D2D'), isTrue);
      expect(_isHighlighted(tester, 'D2D Dashboard'), isFalse);
    });

    testWidgets('never highlights Logout', (tester) async {
      for (final active in DrawerMenu.values) {
        await _pumpDrawer(tester, active);
        expect(_isHighlighted(tester, 'Logout'), isFalse);
      }
    });

    testWidgets('the highlighted label and icon use the accent colour',
        (tester) async {
      await _pumpDrawer(tester, DrawerMenu.collections);

      final active = _tile(tester, 'D2D');
      expect((active.leading as Icon).color, Colors.green);
      expect((active.title as Text).style?.color, Colors.green);
      expect((active.title as Text).style?.fontWeight, FontWeight.w600);

      final inactive = _tile(tester, 'D2D Dashboard');
      expect((inactive.leading as Icon).color, Colors.black87);
      expect((inactive.title as Text).style?.fontWeight, FontWeight.w500);
    });
  });

  group('navigation keeps the highlight in step', () {
    testWidgets('dashboard -> D2D moves the highlight to D2D', (tester) async {
      ApiClient.client = _api();

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/d2d_dashboard',
          routes: {
            '/d2d_dashboard': (_) => const D2dDashboardPage(),
            '/bin_collection': (_) => const BinCollectionScreen(),
            '/login_page': (_) => const Scaffold(body: Text('login')),
          },
        ),
      );
      await tester.pumpAndSettle();

      await _openDrawer(tester);
      expect(_isHighlighted(tester, 'D2D Dashboard'), isTrue);
      expect(_isHighlighted(tester, 'D2D'), isFalse);

      await tester.tap(find.text('D2D'));
      await tester.pumpAndSettle();

      // Now on the scan screen; its drawer must highlight D2D instead.
      expect(find.byType(BinCollectionScreen), findsOneWidget);
      await _openDrawer(tester);
      expect(_isHighlighted(tester, 'D2D'), isTrue);
      expect(_isHighlighted(tester, 'D2D Dashboard'), isFalse);
    });

    testWidgets('D2D -> dashboard moves the highlight back', (tester) async {
      ApiClient.client = _api();

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/bin_collection',
          routes: {
            '/d2d_dashboard': (_) => const D2dDashboardPage(),
            '/bin_collection': (_) => const BinCollectionScreen(),
            '/login_page': (_) => const Scaffold(body: Text('login')),
          },
        ),
      );
      await tester.pumpAndSettle();

      await _openDrawer(tester);
      expect(_isHighlighted(tester, 'D2D'), isTrue);

      await tester.tap(find.text('D2D Dashboard'));
      await tester.pumpAndSettle();

      expect(find.byType(D2dDashboardPage), findsOneWidget);
      await _openDrawer(tester);
      expect(_isHighlighted(tester, 'D2D Dashboard'), isTrue);
      expect(_isHighlighted(tester, 'D2D'), isFalse);
    });

    testWidgets('tapping the active item just closes the drawer',
        (tester) async {
      await _pumpDrawer(tester, DrawerMenu.dashboard);

      await tester.tap(find.text('D2D Dashboard'));
      await tester.pumpAndSettle();

      // No re-navigation to the screen already being shown.
      expect(find.text('dashboard route'), findsNothing);
      expect(find.byType(Drawer), findsNothing);
    });
  });

  group('drawer behaviour', () {
    testWidgets('renders three tiles and prefers the employee name',
        (tester) async {
      await _pumpDrawer(tester, DrawerMenu.dashboard);

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('Welcome Asha K'), findsOneWidget);

      // No ColoredBox may sit between a ListTile and its enclosing Material,
      // which is what the framework assertion guards against.
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('logout blacklists the refresh token then returns to login',
        (tester) async {
      final calledPaths = <String>[];
      ApiClient.client = MockClient((request) async {
        calledPaths.add(request.url.path);
        return http.Response('{}', 200);
      });

      await _pumpDrawer(tester, DrawerMenu.collections);
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(calledPaths, ['/drf_logout/']);
      expect(await AuthService.hasSession(), isFalse);
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('logout still signs out when the network is down',
        (tester) async {
      ApiClient.client = MockClient(
        (request) async => throw http.ClientException('offline'),
      );

      await _pumpDrawer(tester, DrawerMenu.collections);
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(await AuthService.hasSession(), isFalse);
      expect(find.text('login'), findsOneWidget);
    });
  });
}
