import '../../data/database/settings_service.dart';
import '../../data/models/prayer_time_model.dart';
import 'prayer_time_calculator.dart';

/// The kind of azkar content shown at a given moment.
///
/// Rules are evaluated in this priority order (first match wins):
///   1. [kahf]    — Friday, local time within [Jumu'ah + 15 min, Maghrib).
///   2. [morning] — UTC hour in [05:00, 12:00).
///   3. [evening] — UTC hour in [20:00, 24:00) ∪ [00:00, 01:00).
///   4. [general] — everything else (seeded, offline).
enum AzkarWidgetType { morning, evening, kahf, general }

/// A single azkar / duaa entry with an optional source reference.
class AzkarItem {
  const AzkarItem(this.text, {this.reference});

  final String text;
  final String? reference;
}

/// Morning adhkar (أذكار الصباح) — authentic, widely transmitted texts.
const List<AzkarItem> morningAzkar = [
  AzkarItem(
    'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ',
    reference: 'رواه الترمذي',
  ),
  AzkarItem(
    'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ',
    reference: 'رواه أبو داود',
  ),
  AzkarItem(
    'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
    reference: 'رواه مسلم',
  ),
  AzkarItem(
    'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
    reference: 'سورة التوبة 129',
  ),
  AzkarItem(
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
    reference: 'رواه مسلم',
  ),
];

/// Evening adhkar (أذكار المساء) — authentic, widely transmitted texts.
const List<AzkarItem> eveningAzkar = [
  AzkarItem(
    'اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ أَصْبَحْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ',
    reference: 'رواه الترمذي',
  ),
  AzkarItem(
    'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
    reference: 'رواه الترمذي',
  ),
  AzkarItem(
    'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
    reference: 'رواه مسلم',
  ),
  AzkarItem(
    'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ',
    reference: 'رواه ابن ماجه',
  ),
  AzkarItem(
    'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَاللَّهُ أَكْبَرُ، وَلَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
    reference: 'رواه مسلم',
  ),
];

/// General adhkar & duas (أذكار وأدعية عامة) — used as the offline fallback.
const List<AzkarItem> generalAzkar = [
  AzkarItem(
    'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    reference: 'سورة البقرة 201',
  ),
  AzkarItem(
    'اللَّهُمَّ اغْفِرْ لِي ذَنْبِي كُلَّهُ، دِقَّهُ وَجِلَّهُ، وَأَوَّلَهُ وَآخِرَهُ، وَعَلَانِيَتَهُ وَسِرَّهُ',
    reference: 'رواه مسلم',
  ),
  AzkarItem(
    'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
    reference: 'سورة الأنبياء 87',
  ),
  AzkarItem(
    'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
    reference: 'رواه البخاري',
  ),
  AzkarItem(
    'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
    reference: 'صحيح الترغيب',
  ),
  AzkarItem(
    'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي وَاحْلُلْ عُقْدَةً مِّن لِّسَانِي يَفْقَهُوا قَوْلِي',
    reference: 'سورة طه 25-28',
  ),
  AzkarItem(
    'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
    reference: 'سورة آل عمران 173',
  ),
  AzkarItem(
    'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ وَعَلَى آلِهِ وَصَحْبِهِ أَجْمَعِينَ',
    reference: 'دعاء',
  ),
];

/// The fixed item shown while the Friday (Surat Al-Kahf) rule is active.
const AzkarItem kahfItem = AzkarItem(
  'سُورَةُ الْكَهْفِ',
  reference: 'من قرأ سورة الكهف يوم الجمعة أضاء له من النور ما بين الجمعتين',
);

/// Evaluates which azkar content should be shown at [currentPrayerFriday].
///
/// [currentPrayerFriday] is the current moment (pass `DateTime.now()`); the
/// name mirrors the original specification. Absolute time comparisons always
/// use [DateTime.toUtc]. The optional [prayerTimes] lets callers reuse the
/// prayer times already computed by the app; when omitted (or stale) they are
/// derived offline via [PrayerTimeCalculator].
AzkarWidgetType getAzkarType(
  DateTime currentPrayerFriday, {
  List<PrayerTimeModel>? prayerTimes,
}) {
  // 1. Friday special: local Friday + [Jumu'ah + 15 min, Maghrib).
  if (_isInFridayKahfWindow(currentPrayerFriday, prayerTimes)) {
    return AzkarWidgetType.kahf;
  }

  // Absolute (UTC) comparisons for the fixed windows.
  final utc = currentPrayerFriday.toUtc();

  // 2. Morning adhkar: 05:00 UTC – 12:00 UTC.
  if (utc.hour >= 5 && utc.hour < 12) return AzkarWidgetType.morning;

  // 3. Evening adhkar: 20:00 UTC – 01:00 UTC (next day).
  if (utc.hour >= 20 || utc.hour < 1) return AzkarWidgetType.evening;

  // 4. Fallback: general adhkar / duas.
  return AzkarWidgetType.general;
}

/// Returns the content to display for [type], selected offline and seeded by
/// the UTC day/hour so it stays stable during that hour on every device.
AzkarItem getAzkarItem(AzkarWidgetType type, DateTime now) {
  final seed = azkarHourSeed(now);
  switch (type) {
    case AzkarWidgetType.kahf:
      return kahfItem;
    case AzkarWidgetType.morning:
      return morningAzkar[_seededIndex(seed, morningAzkar.length)];
    case AzkarWidgetType.evening:
      return eveningAzkar[_seededIndex(seed, eveningAzkar.length)];
    case AzkarWidgetType.general:
      return generalAzkar[_seededIndex(seed, generalAzkar.length)];
  }
}

/// Deterministic UTC-based seed: hours since the Unix epoch (UTC). Identical
/// across devices and stable for one full hour.
int azkarHourSeed(DateTime now) {
  final utc = now.toUtc();
  final days = utc.difference(DateTime.utc(1970)).inDays;
  return days * 24 + utc.hour;
}

bool _isInFridayKahfWindow(
  DateTime now,
  List<PrayerTimeModel>? providedTimes,
) {
  if (now.weekday != DateTime.friday) return false;

  final times = _sameDayTimes(now, providedTimes);
  DateTime? jumuah;
  DateTime? maghrib;
  for (final t in times) {
    if (t.name == 'Dhuhr') {
      jumuah = t.time;
    } else if (t.name == 'Maghrib') {
      maghrib = t.time;
    }
  }
  if (jumuah == null || maghrib == null) return false;

  final start = jumuah.add(const Duration(minutes: 15));
  return !now.isBefore(start) && now.isBefore(maghrib);
}

/// Uses the provided prayer times only when they belong to the same day as
/// [now]; otherwise recomputes them offline for that exact day (a session
/// crossing midnight must not evaluate against yesterday's times).
List<PrayerTimeModel> _sameDayTimes(
  DateTime now,
  List<PrayerTimeModel>? provided,
) {
  if (provided != null) {
    for (final t in provided) {
      if (t.name == 'Dhuhr' && _isSameDay(t.time, now)) return provided;
    }
  }
  return PrayerTimeCalculator.calculate(
    latitude: SettingsService.latitude,
    longitude: SettingsService.longitude,
    date: now,
  );
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// FNV-1a 32-bit hash → uniform-ish, deterministic index into [length].
int _seededIndex(int seed, int length) {
  var hash = 0x811C9DC5;
  for (var shift = 0; shift < 32; shift += 8) {
    hash ^= (seed >> shift) & 0xFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash % length;
}
