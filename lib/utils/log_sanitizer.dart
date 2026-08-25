import 'dart:convert';

/// Redacts credentials before anything reaches the console.
///
/// Applied to headers, query parameters and both request and response bodies,
/// so tokens and passwords never appear in a log even though the rest of the
/// payload stays readable for debugging.
class LogSanitizer {
  const LogSanitizer._();

  static const String redacted = '***REDACTED***';

  /// Headers whose value is a credential.
  static const Set<String> _sensitiveHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'api-key',
    'x-auth-token',
  };

  /// JSON/query keys that are a credential outright.
  ///
  /// `access` and `refresh` are the JWT fields returned by `/drf_login/` and
  /// `/drf_refresh_token/`, so they are matched exactly rather than by fragment
  /// to avoid redacting unrelated fields that merely contain those words.
  static const Set<String> _sensitiveKeys = {
    'access',
    'refresh',
    'token',
    'password',
    'secret',
    'otp',
    'pin',
    'signature',
    'credential',
    'credentials',
    'authorization',
  };

  /// Key fragments that imply a credential, e.g. `access_token`,
  /// `new_password`, `client_secret`.
  static const List<String> _sensitiveKeyFragments = [
    'password',
    'passwd',
    'token',
    'secret',
    'api_key',
    'apikey',
  ];

  static final JsonEncoder _pretty = JsonEncoder.withIndent('  ');

  static bool isSensitiveKey(String key) {
    final normalized = key.toLowerCase().trim();
    if (_sensitiveKeys.contains(normalized)) return true;
    return _sensitiveKeyFragments.any(normalized.contains);
  }

  /// Masks credential headers, keeping every other header intact.
  static Map<String, String> headers(Map<String, String> source) {
    return {
      for (final entry in source.entries)
        entry.key: _sensitiveHeaders.contains(entry.key.toLowerCase().trim())
            ? _redactHeaderValue(entry.value)
            : entry.value,
    };
  }

  /// Keeps the auth scheme visible, which matters when debugging a 401, and
  /// hides the credential itself: `Bearer ***REDACTED***`.
  static String _redactHeaderValue(String value) {
    final separator = value.indexOf(' ');
    if (separator > 0) {
      return '${value.substring(0, separator)} $redacted';
    }
    return redacted;
  }

  static Map<String, String> queryParameters(Map<String, String> source) {
    return {
      for (final entry in source.entries)
        entry.key: isSensitiveKey(entry.key) ? redacted : entry.value,
    };
  }

  /// Rebuilds [url] with its query parameters masked.
  static String url(Uri url) {
    if (url.queryParameters.isEmpty) return url.toString();
    return url
        .replace(queryParameters: queryParameters(url.queryParameters))
        .toString();
  }

  /// Masks a body and pretty-prints it when it is JSON.
  ///
  /// Pretty-printing is not just cosmetic: Android's logcat truncates long
  /// single lines, so breaking the payload across lines keeps it fully visible.
  static String body(String? raw) {
    if (raw == null) return '(none)';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '(none)';

    try {
      return _pretty.convert(_maskJson(jsonDecode(trimmed)));
    } on FormatException {
      // Not JSON. Could be form-encoded (which may carry a password) or an
      // HTML error page.
      return _maskFormEncoded(trimmed) ?? trimmed;
    }
  }

  static Object? _maskJson(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          '${entry.key}': isSensitiveKey('${entry.key}')
              ? redacted
              : _maskJson(entry.value),
      };
    }
    if (value is List) {
      return value.map(_maskJson).toList();
    }
    return value;
  }

  /// Masks `a=1&password=x` style bodies, or returns null when [raw] does not
  /// look form-encoded.
  static String? _maskFormEncoded(String raw) {
    if (!raw.contains('=') || raw.contains('<') || raw.contains('\n')) {
      return null;
    }
    try {
      final parsed = Uri.splitQueryString(raw);
      if (parsed.isEmpty) return null;
      return queryParameters(parsed)
          .entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('&');
    } catch (_) {
      return null;
    }
  }

  /// Pretty-prints a string map for the log block.
  static String map(Map<String, String> source) {
    if (source.isEmpty) return '(none)';
    return _pretty.convert(source);
  }
}
