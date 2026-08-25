import 'json_parsing.dart';

/// The authenticated user returned by `/drf_login/`.
class UserSession {
  final int id;
  final String username;
  final String? employeeName;
  final String? project;
  final String? zone;
  final String? ward;

  const UserSession({
    required this.id,
    required this.username,
    required this.employeeName,
    required this.project,
    required this.zone,
    required this.ward,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: asInt(json['id']),
      username: asString(json['username']),
      employeeName: asNullableString(json['employee_name']),
      // These arrive as ids or names depending on the serializer, so they are
      // kept as display strings rather than being forced into a numeric type.
      project: asNullableString(json['project']),
      zone: asNullableString(json['zone']),
      ward: asNullableString(json['ward']),
    );
  }

  /// Preferred label for greetings, falling back to the login name.
  String get displayName =>
      (employeeName != null && employeeName!.isNotEmpty)
          ? employeeName!
          : username;
}
