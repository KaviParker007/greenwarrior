import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenwarrior/components/d2d/summary_card.dart';
import 'package:greenwarrior/pages/d2d/d2d_dashboard_page.dart';
import 'package:greenwarrior/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

const _projects = [
  {
    'id': 1,
    'project_code': 'PRJ-A',
    'project_name': 'North City',
    'total_collections': 12,
    'total_houses': 40,
  },
  {
    'id': 2,
    'project_code': 'PRJ-B',
    'project_name': 'South City',
    'total_collections': 0,
    'total_houses': 30,
  },
];

const _zones = [
  {'id': 11, 'zone_code': 'Z-1', 'total_collections': 5, 'total_houses': 20},
];

const _wards = [
  {'id': 21, 'ward_code': 'W-1', 'total_collections': 3, 'total_houses': 10},
];

const _collections = [
  {
    'id': 501,
    'ward_code': 'W-1',
    'project_code': 'PRJ-A',
    'house_name': 'House 12',
    'collected_by_name': 'Asha',
    'collected_on': '2026-08-24T09:15:00Z',
    'device_id': 'abc123',
    'latitude': '12.9716',
    'longitude': '77.5946',
  },
];

/// Serves each D2D endpoint and records the URLs that were requested.
MockClient _api({List<Uri>? seen, Map<String, Object>? overrides}) {
  return MockClient((request) async {
    seen?.add(request.url);
    final path = request.url.path;
    final override = overrides?[path];
    if (override != null) {
      return override is int
          ? _json({'detail': 'error'}, status: override)
          : _json(override);
    }
    switch (path) {
      case '/d2d/drf_collection_by_project/':
        return _json(_projects);
      case '/d2d/drf_collection_by_zone/':
        return _json(_zones);
      case '/d2d/drf_collection_by_ward/':
        return _json(_wards);
      case '/d2d/drf_list_queried_collections/':
        return _json(_collections);
      default:
        return _json({'detail': 'not found'}, status: 404);
    }
  });
}

/// Targets a tab label inside the TabBar, avoiding same-named text elsewhere.
Finder _tab(String label) => find.descendant(
      of: find.byType(TabBar),
      matching: find.text(label),
    );

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: const D2dDashboardPage(),
      routes: {'/login_page': (_) => const Scaffold(body: Text('login'))},
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
      'username': 'collector',
    });
  });

  tearDown(() {
    ApiClient.client = http.Client();
  });

  testWidgets('renders the four tabs and the project summaries', (tester) async {
    ApiClient.client = _api();
    await _pump(tester);

    expect(find.text('D2D Dashboard'), findsOneWidget);
    for (final tab in ['Projects', 'Zones', 'Wards', 'Collections']) {
      expect(_tab(tab), findsOneWidget, reason: 'missing tab $tab');
    }

    // Both projects show, including the one with zero collections.
    expect(find.text('PRJ-A'), findsOneWidget);
    expect(find.text('PRJ-B'), findsOneWidget);
    expect(find.byType(SummaryCard), findsNWidgets(2));
  });

  testWidgets('sorts summaries by code', (tester) async {
    ApiClient.client = _api(
      overrides: {
        // Served out of order on purpose.
        '/d2d/drf_collection_by_project/': [_projects[1], _projects[0]],
      },
    );
    await _pump(tester);

    final codes = tester
        .widgetList<SummaryCard>(find.byType(SummaryCard))
        .map((card) => card.summary.code)
        .toList();
    expect(codes, ['PRJ-A', 'PRJ-B']);
  });

  testWidgets('sends todays date to the summary endpoints', (tester) async {
    final seen = <Uri>[];
    ApiClient.client = _api(seen: seen);
    await _pump(tester);

    final request = seen.firstWhere(
      (uri) => uri.path == '/d2d/drf_collection_by_project/',
    );
    final date = request.queryParameters['collected_date']!;
    // Must be the API's YYYY-MM-DD contract.
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date), isTrue);
  });

  testWidgets('selecting a project scopes the zones request to it',
      (tester) async {
    final seen = <Uri>[];
    ApiClient.client = _api(seen: seen);
    await _pump(tester);

    await tester.tap(find.text('PRJ-A'));
    await tester.pumpAndSettle();

    final zoneRequest = seen.lastWhere(
      (uri) => uri.path == '/d2d/drf_collection_by_zone/',
    );
    expect(zoneRequest.queryParameters['id'], '1');

    // The selection surfaces as a clearable filter chip.
    expect(find.text('Project: PRJ-A'), findsOneWidget);
    expect(find.text('Z-1'), findsOneWidget);
  });

  testWidgets('drilling project -> zone -> ward applies ward precedence',
      (tester) async {
    final seen = <Uri>[];
    ApiClient.client = _api(seen: seen);
    await _pump(tester);

    await tester.tap(find.text('PRJ-A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Z-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('W-1'));
    await tester.pumpAndSettle();

    final wardRequest = seen.lastWhere(
      (uri) => uri.path == '/d2d/drf_collection_by_ward/',
    );
    expect(wardRequest.queryParameters['id'], '11');

    final query = seen.lastWhere(
      (uri) => uri.path == '/d2d/drf_list_queried_collections/',
    );
    // Ward wins: zone and project must not be sent alongside it.
    expect(query.queryParameters['ward'], '21');
    expect(query.queryParameters.containsKey('zone'), isFalse);
    expect(query.queryParameters.containsKey('project'), isFalse);
    expect(query.queryParameters['start_date'], isNotNull);
    expect(query.queryParameters['end_date'], isNotNull);

    expect(find.text('House 12'), findsOneWidget);
  });

  testWidgets('clearing the project filter resets the deeper selections',
      (tester) async {
    ApiClient.client = _api();
    await _pump(tester);

    await tester.tap(find.text('PRJ-A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Z-1'));
    await tester.pumpAndSettle();

    expect(find.text('Project: PRJ-A'), findsOneWidget);
    expect(find.text('Zone: Z-1'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear').first);
    await tester.pumpAndSettle();

    expect(find.text('Project: PRJ-A'), findsNothing);
    expect(find.text('Zone: Z-1'), findsNothing);
  });

  testWidgets('shows an empty state rather than a blank tab', (tester) async {
    ApiClient.client = _api(
      overrides: {'/d2d/drf_collection_by_project/': <Object>[]},
    );
    await _pump(tester);

    expect(find.text('No Projects Found'), findsOneWidget);
    expect(find.byType(SummaryCard), findsNothing);
  });

  testWidgets('shows a friendly error with retry on server failure',
      (tester) async {
    ApiClient.client = _api(
      overrides: {'/d2d/drf_collection_by_project/': 500},
    );
    await _pump(tester);

    expect(find.text('Something Went Wrong'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    // Raw server text must never be shown.
    expect(find.textContaining('detail'), findsNothing);
  });

  testWidgets('redirects to login when the session cannot be refreshed',
      (tester) async {
    ApiClient.client = MockClient(
      (request) async => _json({'detail': 'expired'}, status: 401),
    );
    await _pump(tester);

    expect(find.text('login'), findsOneWidget);
  });

  group('responsive layout', () {
    for (final size in const [
      Size(360, 690), // phone
      Size(768, 1024), // tablet portrait
      Size(1440, 900), // desktop
    ]) {
      testWidgets('lays out without overflow at ${size.width.toInt()}px',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        ApiClient.client = _api();
        await _pump(tester);

        // An overflowing RenderFlex reports an exception, which fails the test.
        expect(tester.takeException(), isNull);
        expect(find.byType(SummaryCard), findsNWidgets(2));

        // Wider viewports must use more than one column.
        final cards = tester
            .widgetList<SummaryCard>(find.byType(SummaryCard))
            .toList();
        expect(cards, hasLength(2));
        final first = tester.getTopLeft(find.byType(SummaryCard).first);
        final second = tester.getTopLeft(find.byType(SummaryCard).last);
        if (size.width >= 768) {
          expect(second.dy, first.dy, reason: 'expected a multi-column row');
        } else {
          expect(second.dy, greaterThan(first.dy),
              reason: 'expected a single column');
        }
      });
    }
  });

  testWidgets('collections tab exposes a capped date range', (tester) async {
    ApiClient.client = _api();
    await _pump(tester);

    await tester.tap(_tab('Collections'));
    await tester.pumpAndSettle();

    expect(find.text('Start Date'), findsOneWidget);
    expect(find.text('End Date'), findsOneWidget);
    expect(find.textContaining('Maximum range is 7 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
