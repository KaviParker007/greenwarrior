import '../models/house_collection.dart';
import '../models/json_parsing.dart';
import 'api_client.dart';

/// Endpoints used by the on-device scan flow.
///
/// Deliberately separate from [D2dService]: these are the mobile/testing APIs,
/// and keeping them out of the reporting service makes it clear they are not
/// part of the D2D dashboard.
class CollectionScanService {
  const CollectionScanService._();

  /// `POST /d2d/drf_collect_house/` -- records a scanned house as collected.
  static Future<void> collectHouse({
    required int houseId,
    required String deviceId,
    double? latitude,
    double? longitude,
  }) async {
    await ApiClient.post(
      '/d2d/drf_collect_house/',
      body: {
        'house_id': houseId,
        'device_id': deviceId,
        'latitude': latitude?.toStringAsFixed(6),
        'longitude': longitude?.toStringAsFixed(6),
      },
    );
  }

  /// `GET /d2d/drf_list_collection_all_temp/`
  ///
  /// Backs the existing scan screen's list only. This is the temporary
  /// mobile-development endpoint and must not be surfaced anywhere else.
  static Future<List<HouseCollection>> listRecentCollections() async {
    final data = await ApiClient.get('/d2d/drf_list_collection_all_temp/');
    return asJsonList(data).map(HouseCollection.fromJson).toList();
  }
}
