import '../data/database/hive_service.dart';
import '../data/models/verse_model.dart';

/// Deterministically selects the "Ayah of the Week".
///
/// The selection is computed entirely offline from:
///   1. the ISO 8601 week number (UTC) — so every Bayan user on Earth sees the
///      same verse during the same week, regardless of timezone, and it changes
///      exactly at Monday 00:00 UTC;
///   2. a stable FNV-1a hash of that week key, mapped into the 6236 verses of
///      the bundled mushaf (verse ids in Hive are sequential 1..6236 in mushaf
///      order, so `id == index + 1`).
///
/// No network, no server, no user state is involved — the result is identical
/// on every device because the input (week key + bundled data) is identical.
class AyahOfWeekService {
  AyahOfWeekService._();

  static const int _totalVerses = 6236;

  /// FNV-1a 32-bit hash — a stable, deterministic hash across all platforms.
  static int _fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// ISO 8601 week (year, week) for a UTC instant.
  static (int, int) _isoWeek(DateTime utc) {
    final thursday = utc.add(Duration(days: 4 - utc.weekday));
    final year = thursday.year;
    final jan1 = DateTime.utc(year, 1, 1);
    final week = (thursday.difference(jan1).inDays ~/ 7) + 1;
    return (year, week);
  }

  /// Stable week key, e.g. "W31-2026". Changes every Monday 00:00 UTC.
  static String get weekKey {
    final (year, week) = _isoWeek(DateTime.now().toUtc());
    return 'W$week-$year';
  }

  /// Human friendly week label, e.g. "31 • 2026".
  static String get weekLabel {
    final (year, week) = _isoWeek(DateTime.now().toUtc());
    return '$week • $year';
  }

  /// The Hive verse id (1..6236) for this week's ayah.
  ///
  /// Re-rolls if the pick lands on id 1 (Al-Fatiha 1:1, the basmalah) so the
  /// featured verse is always a real ayah. The re-roll is deterministic too.
  static int get verseId {
    var index = _fnv1a('bayan-ayah-of-week:$weekKey') % _totalVerses;
    if (index == 0) {
      index = _fnv1a('bayan-ayah-of-week:$weekKey:reroll') % _totalVerses;
    }
    return index + 1;
  }

  /// The [VerseModel] for this week, or null if the verses box isn't seeded yet.
  static VerseModel? get verse => HiveService.getVerse(verseId);

  /// Milliseconds until the next Monday 00:00 UTC (used to schedule a refresh
  /// so the widget rolls over to the new ayah at exactly the right moment).
  static Duration get timeUntilNextWeek {
    final now = DateTime.now().toUtc();
    final nextMonday = DateTime.utc(
      now.year,
      now.month,
      now.day + ((8 - now.weekday) % 7 == 0 ? 7 : (8 - now.weekday) % 7),
    );
    return nextMonday.difference(now);
  }
}
