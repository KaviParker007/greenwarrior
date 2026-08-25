import 'package:flutter/foundation.dart';

/// Non-API diagnostic logging (device info, geolocation, best-effort fallbacks).
///
/// API traffic is logged by [ApiLogger] via [LoggingHttpClient]; this is for
/// everything else. Silent outside debug builds.
class AppLogger {
  const AppLogger._();

  static void error(String message, [Object? error]) {
    if (!kDebugMode) return;
    debugPrint('!!! $message${error == null ? '' : ' :: $error'}');
  }
}
