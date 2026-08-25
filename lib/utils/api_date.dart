import 'package:intl/intl.dart';

/// Date helpers for the API contract, which requires `YYYY-MM-DD`.
///
/// All outbound dates go through [format] so an invalid format can never be
/// sent, and all inbound timestamps go through [formatTimestamp] so a missing
/// or malformed value degrades to a placeholder instead of throwing.
class ApiDate {
  const ApiDate._();

  /// Longest inclusive span the queried-collections endpoint accepts.
  static const int maxRangeInDays = 7;

  static final DateFormat _api = DateFormat('yyyy-MM-dd');
  static final DateFormat _display = DateFormat('dd MMM yyyy');
  static final DateFormat _timestamp = DateFormat('dd MMM yyyy, hh:mm a');

  /// The API wire format, e.g. `2026-08-24`.
  static String format(DateTime date) => _api.format(date);

  static String formatDisplay(DateTime date) => _display.format(date);

  /// Today with the time component stripped, so comparisons stay date-only.
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Whether `start..end` inclusive fits inside the API's 7-day window.
  static bool isWithinMaxRange(DateTime start, DateTime end) =>
      end.difference(start).inDays.abs() <= maxRangeInDays - 1;

  /// Pulls [end] back so the inclusive span never exceeds [maxRangeInDays].
  static DateTime clampEnd(DateTime start, DateTime end) {
    final limit = start.add(const Duration(days: maxRangeInDays - 1));
    return end.isAfter(limit) ? limit : end;
  }

  /// Pushes [start] forward so the inclusive span never exceeds [maxRangeInDays].
  static DateTime clampStart(DateTime start, DateTime end) {
    final limit = end.subtract(const Duration(days: maxRangeInDays - 1));
    return start.isBefore(limit) ? limit : start;
  }

  /// Formats an API timestamp for display, tolerating null/blank/unparseable.
  static String formatTimestamp(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--';
    final parsed = DateTime.tryParse(raw.trim());
    return parsed == null ? raw.trim() : _timestamp.format(parsed.toLocal());
  }
}
