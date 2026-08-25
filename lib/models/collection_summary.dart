import 'json_parsing.dart';

/// The level a [CollectionSummary] describes.
enum SummaryLevel {
  project('Project'),
  zone('Zone'),
  ward('Ward');

  const SummaryLevel(this.label);

  final String label;
}

/// One row from the project/zone/ward collection-summary endpoints.
///
/// The three endpoints return the same shape apart from their code and name
/// keys, so a single model backs all of them and lets one card widget render
/// each level without duplicating UI.
class CollectionSummary {
  final int id;
  final String code;
  final String? name;
  final int totalCollections;
  final int totalHouses;
  final SummaryLevel level;

  const CollectionSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.totalCollections,
    required this.totalHouses,
    required this.level,
  });

  factory CollectionSummary.fromProjectJson(Map<String, dynamic> json) {
    return CollectionSummary(
      id: asInt(json['id']),
      code: asString(json['project_code'], fallback: 'Unknown project'),
      name: asNullableString(json['project_name']),
      totalCollections: asInt(json['total_collections']),
      totalHouses: asInt(json['total_houses']),
      level: SummaryLevel.project,
    );
  }

  factory CollectionSummary.fromZoneJson(Map<String, dynamic> json) {
    return CollectionSummary(
      id: asInt(json['id']),
      code: asString(json['zone_code'], fallback: 'Unknown zone'),
      name: asNullableString(json['zone_name']),
      totalCollections: asInt(json['total_collections']),
      totalHouses: asInt(json['total_houses']),
      level: SummaryLevel.zone,
    );
  }

  factory CollectionSummary.fromWardJson(Map<String, dynamic> json) {
    return CollectionSummary(
      id: asInt(json['id']),
      code: asString(json['ward_code'], fallback: 'Unknown ward'),
      name: asNullableString(json['ward_name']),
      totalCollections: asInt(json['total_collections']),
      totalHouses: asInt(json['total_houses']),
      level: SummaryLevel.ward,
    );
  }

  /// Share of houses covered, or null when the house count is unknown.
  double? get coverage {
    if (totalHouses <= 0) return null;
    return (totalCollections / totalHouses).clamp(0.0, 1.0);
  }
}
