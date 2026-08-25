import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenwarrior/components/d2d/collection_card.dart';
import 'package:greenwarrior/pages/Qr_Scan/bin_collection.dart';
import 'package:greenwarrior/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: const BinCollectionScreen(),
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

  testWidgets('empty state keeps its Scan Now call to action', (tester) async {
    ApiClient.client = MockClient((request) async => http.Response('[]', 200));
    await _pump(tester);

    expect(find.text('No Collections Yet'), findsOneWidget);
    // Regression guard: this CTA existed before the shared-state refactor.
    expect(find.text('Scan Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders collections returned by the device endpoint',
      (tester) async {
    ApiClient.client = MockClient(
      (request) async => http.Response(
        jsonEncode([
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
        ]),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await _pump(tester);

    expect(find.byType(CollectionCard), findsOneWidget);
    expect(find.text('House 12'), findsOneWidget);
    expect(find.text('GPS Captured'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a friendly error instead of a raw server body',
      (tester) async {
    ApiClient.client = MockClient(
      (request) async => http.Response('<html>oops</html>', 500),
    );
    await _pump(tester);

    expect(find.text('Something Went Wrong'), findsOneWidget);
    expect(find.textContaining('html'), findsNothing);
  });
}
