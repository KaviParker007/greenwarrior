import 'json_parsing.dart';

/// Payload decoded from a scanned house/bin QR code.
class BinData {
  final int? id;
  final String? project;
  final String? binNumber;
  final int? zone;
  final int? ward;
  String? location;
  String? pointName;
  double? latitude;
  double? longitude;

  BinData({
    this.id,
    this.project,
    this.binNumber,
    this.zone,
    this.ward,
    this.location,
    this.pointName,
    this.latitude,
    this.longitude,
  });

  factory BinData.fromJson(Map<String, dynamic> json) {
    return BinData(
      id: asInt(json['id']),
      project: asString(json['project']),
      binNumber: asString(json['bin_number']),
      zone: asInt(json['zone']),
      ward: asInt(json['ward']),
      location: asString(json['location']),
      pointName: asString(json['point_name']),
      latitude: asNullableDouble(json['latitude']),
      longitude: asNullableDouble(json['longitude']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project': project,
      'bin_number': binNumber,
      'zone': zone,
      'ward': ward,
      'location': location,
      'point_name': pointName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  bool get isLocationMissing {
    return (location == null || location!.isEmpty) ||
        latitude == null ||
        longitude == null;
  }
}
