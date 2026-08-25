import 'package:flutter_test/flutter_test.dart';
import 'package:greenwarrior/models/collection_summary.dart';
import 'package:greenwarrior/models/house_collection.dart';
import 'package:greenwarrior/models/json_parsing.dart';
import 'package:greenwarrior/services/d2d_service.dart';
import 'package:greenwarrior/utils/api_date.dart';

void main() {
  group('ApiDate', () {
    test('formats dates in the API contract format', () {
      expect(ApiDate.format(DateTime(2026, 8, 24)), '2026-08-24');
      // Single-digit month/day must stay zero-padded.
      expect(ApiDate.format(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('today has no time component', () {
      final today = ApiDate.today();
      expect(today.hour, 0);
      expect(today.minute, 0);
      expect(today.second, 0);
    });

    test('accepts a range of exactly 7 days and rejects 8', () {
      final start = DateTime(2026, 8, 1);
      expect(ApiDate.isWithinMaxRange(start, DateTime(2026, 8, 7)), isTrue);
      expect(ApiDate.isWithinMaxRange(start, DateTime(2026, 8, 8)), isFalse);
    });

    test('clampEnd pulls an over-long range back to the 7-day limit', () {
      final start = DateTime(2026, 8, 1);
      expect(
        ApiDate.clampEnd(start, DateTime(2026, 8, 30)),
        DateTime(2026, 8, 7),
      );
      // A range already inside the window is left untouched.
      expect(
        ApiDate.clampEnd(start, DateTime(2026, 8, 3)),
        DateTime(2026, 8, 3),
      );
    });

    test('clampStart pushes an over-long range forward to the limit', () {
      final end = DateTime(2026, 8, 30);
      expect(
        ApiDate.clampStart(DateTime(2026, 8, 1), end),
        DateTime(2026, 8, 24),
      );
    });

    test('formatTimestamp degrades safely instead of throwing', () {
      expect(ApiDate.formatTimestamp(null), '--');
      expect(ApiDate.formatTimestamp(''), '--');
      expect(ApiDate.formatTimestamp('   '), '--');
      // Unparseable input is echoed back rather than crashing the card.
      expect(ApiDate.formatTimestamp('not-a-date'), 'not-a-date');
      expect(ApiDate.formatTimestamp('2026-08-24T10:30:00Z'), contains('2026'));
    });
  });

  group('filter precedence (ward > zone > project)', () {
    test('sends only ward when all three are selected', () {
      expect(
        D2dService.collectionFilters(projectId: 1, zoneId: 2, wardId: 3),
        {'ward': '3'},
      );
    });

    test('sends only zone when ward is absent', () {
      expect(
        D2dService.collectionFilters(projectId: 1, zoneId: 2),
        {'zone': '2'},
      );
    });

    test('sends project only when it is the sole selection', () {
      expect(D2dService.collectionFilters(projectId: 1), {'project': '1'});
    });

    test('sends nothing when no filter is selected', () {
      expect(D2dService.collectionFilters(), isEmpty);
    });
  });

  group('json coercion', () {
    test('reads numbers whether they arrive as num or string', () {
      expect(asInt(7), 7);
      expect(asInt('7'), 7);
      expect(asInt(7.9), 7);
      expect(asInt(null), 0);
      expect(asInt('not a number'), 0);
    });

    test('treats blank strings as absent', () {
      expect(asNullableString(''), isNull);
      expect(asNullableString('   '), isNull);
      expect(asNullableString(' value '), 'value');
    });

    test('unwraps both a bare list and a paginated envelope', () {
      expect(asJsonList([{'a': 1}]), hasLength(1));
      expect(asJsonList({'results': [{'a': 1}, {'b': 2}]}), hasLength(2));
      // Anything unexpected yields an empty list rather than throwing.
      expect(asJsonList(null), isEmpty);
      expect(asJsonList('oops'), isEmpty);
    });
  });

  group('CollectionSummary', () {
    test('parses a project row', () {
      final summary = CollectionSummary.fromProjectJson({
        'id': 4,
        'project_code': 'PRJ-1',
        'project_name': 'North City',
        'total_collections': 12,
        'total_houses': 40,
      });

      expect(summary.id, 4);
      expect(summary.code, 'PRJ-1');
      expect(summary.name, 'North City');
      expect(summary.totalCollections, 12);
      expect(summary.totalHouses, 40);
      expect(summary.level, SummaryLevel.project);
      expect(summary.coverage, closeTo(0.3, 0.0001));
    });

    test('keeps a zero-collection row usable', () {
      final summary = CollectionSummary.fromZoneJson({
        'id': 9,
        'zone_code': 'Z-9',
        'total_collections': 0,
        'total_houses': 25,
      });

      expect(summary.totalCollections, 0);
      expect(summary.coverage, 0.0);
      expect(summary.level, SummaryLevel.zone);
    });

    test('survives missing and null fields', () {
      final summary = CollectionSummary.fromWardJson(const {});

      expect(summary.id, 0);
      expect(summary.code, 'Unknown ward');
      expect(summary.name, isNull);
      expect(summary.totalCollections, 0);
      expect(summary.totalHouses, 0);
      // No houses means coverage is unknown, not a division by zero.
      expect(summary.coverage, isNull);
    });

    test('coverage never exceeds 100% even if counts disagree', () {
      final summary = CollectionSummary.fromWardJson({
        'id': 1,
        'ward_code': 'W-1',
        'total_collections': 50,
        'total_houses': 10,
      });
      expect(summary.coverage, 1.0);
    });
  });

  group('HouseCollection', () {
    test('parses a full record', () {
      final collection = HouseCollection.fromJson({
        'id': 55,
        'ward_code': 'W-2',
        'project_code': 'PRJ-1',
        'house_name': 'House 12',
        'collected_by_name': 'Asha',
        'collected_on': '2026-08-24T09:15:00Z',
        'device_id': 'abc123',
        'latitude': '12.971600',
        'longitude': '77.594600',
        'house': 12,
        'collected_by': 3,
      });

      expect(collection.id, 55);
      expect(collection.houseName, 'House 12');
      expect(collection.hasLocation, isTrue);
    });

    test('coerces numeric coordinates instead of throwing a type error', () {
      // The old model declared these as String? and assigned raw dynamic values,
      // so a numeric payload crashed at runtime.
      final collection = HouseCollection.fromJson({
        'id': 1,
        'latitude': 12.9716,
        'longitude': 77.5946,
      });

      expect(collection.latitude, '12.9716');
      expect(collection.longitude, '77.5946');
      expect(collection.hasLocation, isTrue);
    });

    test('reports missing coordinates as no location', () {
      final collection = HouseCollection.fromJson(const {'id': 2});

      expect(collection.hasLocation, isFalse);
      expect(collection.houseName, 'Unnamed house');
      expect(collection.wardCode, '--');
    });
  });
}
