/// Defensive JSON coercion shared by the API models.
///
/// The endpoints return numbers as either JSON numbers or strings depending on
/// the serializer, and optional fields may be absent or null. These helpers
/// keep that handling in one place so no model throws on a malformed payload.
library;

int asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

int? asNullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String asString(Object? value, {String fallback = ''}) {
  final parsed = asNullableString(value);
  return parsed ?? fallback;
}

String? asNullableString(Object? value) {
  if (value == null) return null;
  final text = value is String ? value.trim() : value.toString().trim();
  return text.isEmpty ? null : text;
}

double? asNullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Extracts a list payload, tolerating both a bare array and a paginated
/// `{"results": [...]}` envelope.
List<Map<String, dynamic>> asJsonList(Object? data) {
  if (data is List) {
    return data.whereType<Map<String, dynamic>>().toList();
  }
  if (data is Map<String, dynamic>) {
    final results = data['results'];
    if (results is List) {
      return results.whereType<Map<String, dynamic>>().toList();
    }
  }
  return const <Map<String, dynamic>>[];
}
