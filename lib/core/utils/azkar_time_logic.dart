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
  const AzkarItem(
    this.text, {
    this.reference,
    this.referenceEn,
    this.referenceUr,
    this.textEn,
    this.textUr,
  });

  final String text;
  final String? reference;
  final String? referenceEn;
  final String? referenceUr;
  final String? textEn;
  final String? textUr;

  String? translatedReference(String lang) => switch (lang) {
    'en' => referenceEn,
    'ur' => referenceUr,
    _ => reference,
  };

  String? translatedText(String lang) => switch (lang) {
    'en' => textEn,
    'ur' => textUr,
    _ => null,
  };
}

/// Morning adhkar (أذكار الصباح) — authentic, widely transmitted texts.
const List<AzkarItem> morningAzkar = [
  AzkarItem(
    'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ',
    reference: 'رواه الترمذي',
    referenceEn: 'Narrated by At-Tirmidhi',
    referenceUr: 'روایت ترمذی',
    textEn:
        'O Allah, by You we have entered the morning, by You we have entered the evening, by You we live, by You we die, and to You is the resurrection.',
    textUr:
        'اے اللہ! تیرے ذریعے ہم نے صبح کی، تیرے ذریعے ہم نے شام کی، تیرے ذریعے ہم جیتے ہیں، تیرے ذریعے ہم مرتے ہیں، اور تیری ہی طرف اٹھائے جائیں گے۔',
  ),
  AzkarItem(
    'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ',
    reference: 'رواه أبو داود',
    referenceEn: 'Narrated by Abu Dawud',
    referenceUr: 'روایت ابوداؤد',
    textEn:
        'O Allah, grant me health in my body. O Allah, grant me health in my hearing. O Allah, grant me health in my sight. There is no god but You.',
    textUr:
        'اے اللہ! میرے جسم میں عافیت دے۔ اے اللہ! میرے کان میں عافیت دے۔ اے اللہ! میری آنکھوں میں عافیت دے۔ تیرے سوا کوئی معبود نہیں۔',
  ),
  AzkarItem(
    'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
    reference: 'رواه مسلم',
    referenceEn: 'Narrated by Muslim',
    referenceUr: 'روایت مسلم',
    textEn:
        'I seek refuge in the perfect words of Allah from the evil of that which He has created.',
    textUr:
        'میں اللہ کے کامل کلمات کی پناہ مانگتا ہوں اس کی تمام مخلوق کے شر سے۔',
  ),
  AzkarItem(
    'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
    reference: 'سورة التوبة 129',
    referenceEn: 'Surah At-Tawbah 129',
    referenceUr: 'سورۃ التوبہ 129',
    textEn:
        'Allah is sufficient for me. There is no god but Him. In Him I put my trust, and He is the Lord of the Great Throne.',
    textUr:
        'اللہ میرے لیے کافی ہے۔ اس کے سوا کوئی معبود نہیں۔ میں نے اس پر بھروسہ کیا اور وہ عرش عظیم کا رب ہے۔',
  ),
  AzkarItem(
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
    reference: 'رواه مسلم',
    referenceEn: 'Narrated by Muslim',
    referenceUr: 'روایت مسلم',
    textEn:
        'Glory be to Allah and praise be to Him, as many times as His creation, as much as pleases Him, as heavy as His Throne, and as much as the ink of His words.',
    textUr:
        'اللہ پاک ہے اور اس کی تعریف ہے اتنی بار جتنی اس کی مخلوق ہے، جتنا اس کو پسند ہے، جتنا اس کا عرش ہے، اور جتنا اس کے کلمات کا سیاہی ہے۔',
  ),
];

/// Evening adhkar (أذكار المساء) — authentic, widely transmitted texts.
const List<AzkarItem> eveningAzkar = [
  AzkarItem(
    'اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ أَصْبَحْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ الْمَصِيرُ',
    reference: 'رواه الترمذي',
    referenceEn: 'Narrated by At-Tirmidhi',
    referenceUr: 'روایت ترمذی',
    textEn:
        'O Allah, by You we have entered the evening, by You we have entered the morning, by You we live, by You we die, and to You is our return.',
    textUr:
        'اے اللہ! تیرے ذریعے ہم نے شام کی، تیرے ذریعے ہم نے صبح کی، تیرے ذریعے ہم جیتے ہیں، تیرے ذریعے ہم مرتے ہیں، اور تیری ہی طرف لوٹ کر جائیں گے۔',
  ),
  AzkarItem(
    'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
    reference: 'رواه الترمذي',
    referenceEn: 'Narrated by At-Tirmidhi',
    referenceUr: 'روایت ترمذی',
    textEn:
        'In the name of Allah, with Whose name nothing on earth or in heaven can cause harm, and He is the All-Hearing, the All-Knowing.',
    textUr:
        'اللہ کے نام سے جس کے نام کے ساتھ زمین آسمان میں کوئی چیز نقصان نہیں دے سکتی اور وہ سننے والا جاننے والا ہے۔',
  ),
  AzkarItem(
    'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
    reference: 'رواه مسلم',
    referenceEn: 'Narrated by Muslim',
    referenceUr: 'روایت مسلم',
    textEn:
        'I seek refuge in the perfect words of Allah from the evil of that which He has created.',
    textUr:
        'میں اللہ کے کامل کلمات کی پناہ مانگتا ہوں اس کی تمام مخلوق کے شر سے۔',
  ),
  AzkarItem(
    'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْعَفْوَ وَالْعَافِيَةَ فِي الدُّنْيَا وَالْآخِرَةِ',
    reference: 'رواه ابن ماجه',
    referenceEn: 'Narrated by Ibn Majah',
    referenceUr: 'روایت ابن ماجہ',
    textEn:
        'O Allah, I ask You for forgiveness and well-being in this world and in the Hereafter.',
    textUr:
        'اے اللہ! میں تجھ سے دنیا و آخرت میں معافیت اور عافیت مانگتا ہوں۔',
  ),
  AzkarItem(
    'سُبْحَانَ اللَّهِ وَالْحَمْدُ لِلَّهِ وَاللَّهُ أَكْبَرُ، وَلَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
    reference: 'رواه مسلم',
    referenceEn: 'Narrated by Muslim',
    referenceUr: 'روایت مسلم',
    textEn:
        'Glory be to Allah, praise be to Allah, and Allah is the Greatest. There is no god but Allah alone, with no partner. His is the dominion and His is the praise, and He has power over all things.',
    textUr:
        'اللہ پاک ہے، اللہ کی تعریف ہے، اور اللہ سب سے بڑا ہے۔ اللہ کے سوا کوئی معبود نہیں، وہ اکیلا ہے، اس کا کوئی شریک نہیں۔ اسی کی بادشاہی ہے اور اسی کی تعریف ہے اور وہ ہر چیز پر قادر ہے۔',
  ),
];

/// General adhkar & duas (أذكار وأدعية عامة) — used as the offline fallback.
const List<AzkarItem> generalAzkar = [
  AzkarItem(
    'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    reference: 'سورة البقرة 201',
    referenceEn: 'Surah Al-Baqarah 201',
    referenceUr: 'سورۃ البقرة 201',
    textEn:
        'Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.',
    textUr:
        'اے ہمارے رب! ہمیں دنیا میں بھی بھلائی دے اور آخرت میں بھی بھلائی دے اور ہمیں آگ کے عذاب سے بچا۔',
  ),
  AzkarItem(
    'اللَّهُمَّ اغْفِرْ لِي ذَنْبِي كُلَّهُ، دِقَّهُ وَجِلَّهُ، وَأَوَّلَهُ وَآخِرَهُ، وَعَلَانِيَتَهُ وَسِرَّهُ',
    reference: 'رواه مسلم',
    referenceEn: 'Narrated by Muslim',
    referenceUr: 'روایت مسلم',
    textEn:
        'O Allah, forgive me all my sins, the minor and the major, the first and the last, the open and the secret.',
    textUr:
        'اے اللہ! میرے تمام گناہ معاف فرما، چھوے اور بڑے، پہلے اور آخری، ظاہری اور پوشیدہ۔',
  ),
  AzkarItem(
    'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
    reference: 'سورة الأنبياء 87',
    referenceEn: 'Surah Al-Anbiya 87',
    referenceUr: 'سورۃ الانبیاء 87',
    textEn:
        'There is no god but You. Glory be to You. Indeed, I have been among the wrongdoers.',
    textUr:
        'تیرے سوا کوئی معبود نہیں۔ تیری پاکی ہے۔ بے شک میں ظالموں میں سے تھا۔',
  ),
  AzkarItem(
    'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
    reference: 'رواه البخاري',
    referenceEn: 'Narrated by Al-Bukhari',
    referenceUr: 'روایت بخاری',
    textEn:
        'O Allah, I seek refuge in You from worry and grief, from helplessness and laziness, from miserliness and cowardice, from being overwhelmed by debt and overpowered by men.',
    textUr:
        'اے اللہ! میں تجھ سے پناہ مانگتا ہوں فکر اور غم سے، بے بسی اور سستی سے، کنجوسی اور بزدلی سے، قرض کے غلبے اور لوغوں کی زیر و زبر سے۔',
  ),
  AzkarItem(
    'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
    reference: 'صحيح الترغيب',
    referenceEn: 'As-Silsilah As-Sahihah',
    referenceUr: 'سلسلۃ صحیحہ',
    textEn:
        'O Ever-Living, O Sustainer, by Your mercy I seek help. Set right all my affairs and do not leave me to myself even for the blink of an eye.',
    textUr:
        'اے دائمی زندہ، اے قائم رکھنے والے! تیری رحمت سے مدد مانگتا ہوں۔ میرے سارے معاملات درست کر دے اور مجھے ایک پل کے لیے بھی اپنے آپ پر نہ چھوڑ۔',
  ),
  AzkarItem(
    'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي وَاحْلُلْ عُقْدَةً مِّن لِّسَانِي يَفْقَهُوا قَوْلِي',
    reference: 'سورة طه 25-28',
    referenceEn: 'Surah Taha 25-28',
    referenceUr: 'سورۃ طٰہ 25-28',
    textEn:
        'My Lord, expand for me my breast, ease for me my task, and untie the knot from my tongue so that they may understand my speech.',
    textUr:
        'اے میرے رب! میرا سینہ کھول دے، میرا کام آسان کر دے، اور میری زبان کی گرہ کھول دے تاکہ لوگ میری بات سمجھ سکیں۔',
  ),
  AzkarItem(
    'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
    reference: 'سورة آل عمران 173',
    referenceEn: 'Surah Ali Imran 173',
    referenceUr: 'سورۃ آل عمران 173',
    textEn: 'Allah is sufficient for us, and He is the best Disposer of affairs.',
    textUr: 'اللہ ہمارے لیے کافی ہے اور وہ بہترین کارساز ہے۔',
  ),
  AzkarItem(
    'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ وَعَلَى آلِهِ وَصَحْبِهِ أَجْمَعِينَ',
    reference: 'دعاء',
    referenceEn: 'Supplication',
    referenceUr: 'دعا',
    textEn:
        'O Allah, send blessings and peace upon our Prophet Muhammad and upon his family and all his companions.',
    textUr:
        'اے اللہ! ہمارے نبی محمدؐ اور اس کے خاندان اور اس کے سارے صحابہ پر درود و سلام بھیج۔',
  ),
];

/// The fixed item shown while the Friday (Surat Al-Kahf) rule is active.
const AzkarItem kahfItem = AzkarItem(
  'سُورَةُ الْكَهْفِ',
  reference: 'من قرأ سورة الكهف يوم الجمعة أضاء له من النور ما بين الجمعتين',
  referenceEn: 'Whoever reads Surat Al-Kahf on Friday, Allah will illuminate him with light between the two Fridays',
  referenceUr: 'جو شخص جمعے کو سورۃ کہف پڑھے اسے اللہ دونوں جمعوں کے درمیان نور سے منور فرماتا ہے',
  textEn: 'Surat Al-Kahf',
  textUr: 'سورۃ کہف',
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
