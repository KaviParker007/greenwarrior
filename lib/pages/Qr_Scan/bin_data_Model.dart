class Vehicle {
  final int id;
  final String vehicleNumber;
  final String vehicleType;

  Vehicle({
    required this.id,
    required this.vehicleNumber,
    required this.vehicleType,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      vehicleNumber: json['vehicle_number'] as String,
      vehicleType: json['vehicle_type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
    };
  }
}

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
      id: json['id'] ?? 0,
      project: json['project'] ?? '',
      binNumber: json['bin_number'] ?? '',
      zone: json['zone'] ?? 0,
      ward: json['ward'] ?? 0,
      location: json['location'] ?? '',
      pointName: json['point_name'] ?? '',
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
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

  HouseCollection({
    required this.id,
    required this.wardCode,
    required this.projectCode,
    required this.houseName,
    required this.collectedByName,
    required this.collectedOn,
    required this.deviceId,
    this.latitude,
    this.longitude,
    required this.house,
    required this.collectedBy,
  });

  factory HouseCollection.fromJson(Map<String, dynamic> json) {
    return HouseCollection(
      id: json['id'] ?? 0,
      wardCode: json['ward_code'] ?? '',
      projectCode: json['project_code'] ?? '',
      houseName: json['house_name'] ?? '',
      collectedByName: json['collected_by_name'] ?? '',
      collectedOn: json['collected_on'] ?? '',
      deviceId: json['device_id'] ?? '',
      latitude: json['latitude'],
      longitude: json['longitude'],
      house: json['house'] ?? 0,
      collectedBy: json['collected_by'] ?? 0,
    );
  }
}