import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';

/// Resolves the device identifier sent with a collection submission.
///
/// Replaces the copy of this logic that previously sat in both the auth and
/// login pages. The value is resolved on demand and cached in memory and in
/// preferences, so it survives restarts and is not tied to the user session.
class DeviceService {
  const DeviceService._();

  static const String _key = 'deviceId';
  static String? _cached;

  static Future<String> deviceId() async {
    final cached = _cached;
    if (cached != null && cached.isNotEmpty) return cached;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null && stored.isNotEmpty) {
      return _cached = stored;
    }

    final resolved = await _resolve();
    if (resolved.isNotEmpty) {
      await prefs.setString(_key, resolved);
      _cached = resolved;
    }
    return resolved;
  }

  static Future<String> _resolve() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        return (await info.androidInfo).id;
      }
      if (Platform.isIOS) {
        return (await info.iosInfo).identifierForVendor ?? '';
      }
    } catch (error) {
      AppLogger.error('Could not resolve device id', error);
    }
    return '';
  }
}
