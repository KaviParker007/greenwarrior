import 'package:flutter/foundation.dart';

import '../models/collection_summary.dart';
import '../models/house_collection.dart';
import '../models/json_parsing.dart';
import '../utils/api_date.dart';
import 'api_client.dart';

/// The D2D collection endpoints.
///
/// Only the four reporting endpoints are exposed here. The internal
/// `drf_list_collected_house/` and `drf_list_collection_all_temp/` endpoints are
/// intentionally absent: they are mobile/testing APIs and must not be surfaced
/// in the reporting UI.
class D2dService {
  const D2dService._();

  /// `GET /d2d/drf_collection_by_project/`
  ///
  /// Projects the user can access, including those with zero collections,
  /// sorted by `project_code`.
  static Future<List<CollectionSummary>> collectionByProject({
    DateTime? collectedDate,
  }) async {
    final data = await ApiClient.get(
      '/d2d/drf_collection_by_project/',
      query: {'collected_date': ApiDate.format(collectedDate ?? ApiDate.today())},
    );
    return _summaries(data, CollectionSummary.fromProjectJson);
  }

  /// `GET /d2d/drf_collection_by_zone/`
  ///
  /// Zones the user can access, including those with zero collections, sorted
  /// by `zone_code`. Pass [projectId] to scope the zones to one project.
  static Future<List<CollectionSummary>> collectionByZone({
    DateTime? collectedDate,
    int? projectId,
  }) async {
    final data = await ApiClient.get(
      '/d2d/drf_collection_by_zone/',
      query: {
        'collected_date': ApiDate.format(collectedDate ?? ApiDate.today()),
        if (projectId != null) 'id': '$projectId',
      },
    );
    return _summaries(data, CollectionSummary.fromZoneJson);
  }

  /// `GET /d2d/drf_collection_by_ward/`
  ///
  /// Wards the user can access, including those with zero collections, sorted
  /// by `ward_code`. Pass [zoneId] to scope the wards to one zone.
  static Future<List<CollectionSummary>> collectionByWard({
    DateTime? collectedDate,
    int? zoneId,
  }) async {
    final data = await ApiClient.get(
      '/d2d/drf_collection_by_ward/',
      query: {
        'collected_date': ApiDate.format(collectedDate ?? ApiDate.today()),
        if (zoneId != null) 'id': '$zoneId',
      },
    );
    return _summaries(data, CollectionSummary.fromWardJson);
  }

  /// `GET /d2d/drf_list_queried_collections/`
  ///
  /// Collections in a date range, newest first. The range defaults to today and
  /// is capped at [ApiDate.maxRangeInDays] to match the API limit.
  ///
  /// The API applies filter precedence `ward > zone > project`, so only the most
  /// specific selected filter is sent rather than all three.
  static Future<List<HouseCollection>> queriedCollections({
    DateTime? startDate,
    DateTime? endDate,
    int? projectId,
    int? zoneId,
    int? wardId,
  }) async {
    final start = startDate ?? ApiDate.today();
    final end = ApiDate.clampEnd(start, endDate ?? ApiDate.today());

    final data = await ApiClient.get(
      '/d2d/drf_list_queried_collections/',
      query: {
        'start_date': ApiDate.format(start),
        'end_date': ApiDate.format(end),
        ...collectionFilters(
          projectId: projectId,
          zoneId: zoneId,
          wardId: wardId,
        ),
      },
    );

    final collections = asJsonList(data)
        .map(HouseCollection.fromJson)
        .toList(growable: false);

    // The API already orders by `collected_on` descending; sorting here keeps
    // the display order guaranteed regardless of payload order.
    final ordered = List<HouseCollection>.of(collections)
      ..sort((a, b) {
        final left = DateTime.tryParse(a.collectedOn);
        final right = DateTime.tryParse(b.collectedOn);
        if (left == null && right == null) return b.id.compareTo(a.id);
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });
    return ordered;
  }

  /// Builds the location filter for the queried-collections endpoint.
  ///
  /// The API resolves conflicts as `ward > zone > project`, so only the most
  /// specific selected filter is emitted. Sending all three would be redundant
  /// and could disagree with each other.
  @visibleForTesting
  static Map<String, String> collectionFilters({
    int? projectId,
    int? zoneId,
    int? wardId,
  }) {
    if (wardId != null) return {'ward': '$wardId'};
    if (zoneId != null) return {'zone': '$zoneId'};
    if (projectId != null) return {'project': '$projectId'};
    return const <String, String>{};
  }

  /// Maps a payload to summaries sorted by their code, as each endpoint's
  /// contract requires.
  static List<CollectionSummary> _summaries(
    Object? data,
    CollectionSummary Function(Map<String, dynamic>) build,
  ) {
    final summaries = asJsonList(data).map(build).toList();
    summaries.sort(
      (a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()),
    );
    return summaries;
  }
}
