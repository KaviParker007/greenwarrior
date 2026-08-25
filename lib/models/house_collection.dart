import 'json_parsing.dart';

/// A single door-to-door collection record.
///
/// Returned by the queried-collections endpoint and by the collection list the
/// scan flow refreshes after a submission.
class HouseCollection {
  final int id;
  final String wardCode;
  final String projectCode;
  final String houseName;
  final String collectedByName;
  final String collectedOn;
  final String deviceId;
  final String? latitude;
  final String? longitude;
  final int house;
  final int collectedBy;

  const HouseCollection({
    required this.id,
    required this.wardCode,
    required this.projectCode,
    required this.houseName,
    required this.collectedByName,
    required this.collectedOn,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.house,
    required this.collectedBy,
  });

  factory HouseCollection.fromJson(Map<String, dynamic> json) {
    return HouseCollection(
      id: asInt(json['id']),
      wardCode: asString(json['ward_code'], fallback: '--'),
      projectCode: asString(json['project_code'], fallback: '--'),
      houseName: asString(json['house_name'], fallback: 'Unnamed house'),
      collectedByName: asString(json['collected_by_name'], fallback: '--'),
      collectedOn: asString(json['collected_on']),
      deviceId: asString(json['device_id'], fallback: '--'),
      // Coerced rather than cast: the serializer may emit these as numbers.
      latitude: asNullableString(json['latitude']),
      longitude: asNullableString(json['longitude']),
      house: asInt(json['house']),
      collectedBy: asInt(json['collected_by']),
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
}
