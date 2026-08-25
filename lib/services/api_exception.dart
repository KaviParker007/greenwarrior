/// An API failure carrying a message that is safe to show to the user.
///
/// Raw server payloads are never surfaced directly; [ApiClient] maps status
/// codes and error bodies onto friendly text before throwing.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException(${statusCode ?? '-'}): $message';
}

/// Thrown when the access token could not be refreshed and the user has to
/// sign in again. Screens treat this as a signal to return to the login page.
class SessionExpiredException extends ApiException {
  const SessionExpiredException()
      : super(
          'Your session has expired. Please log in again.',
          statusCode: 401,
        );
}
