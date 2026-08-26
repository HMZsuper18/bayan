import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:bayan/core/utils/quran_text_normalizer.dart';
import '../models/surah_model.dart';
import '../models/verse_model.dart';
import '../models/reciter_model.dart';
import 'hive_service.dart';

class SeedData {
  SeedData._();

  /// Bump to re-seed verses after the text pipeline changes. The Quranic text
  /// is sacred — normalization only ever *repositions* marks (attaching waqf
  /// signs to the preceding letter) and never deletes an authentic mark. The
  /// bundled font (KFGQPC UthmanicHafs1 Ver09) covers every codepoint in the
  /// data, including U+0622 (آ), U+0670 (superscript alef) and U+06DE (۞).
  static const _versesSource = 'uthmani_v5';

  static String? _cachedJson;
  static String? _cachedSurahsJson;

  static Future<String> _loadQuran() async {
    _cachedJson ??= await rootBundle.loadString('assets/data/quran.json');
    return _cachedJson!;
  }

  static Future<void> seedAll() async {
    await Future.wait([
      _seedSurahs(),
      _seedVersesAndTafseer(),
      _seedTranslations(),
      _seedReciters(),
    ]);
  }

  static Future<void> _seedSurahs() async {
    final box = HiveService.surahsBox;
    if (box.isNotEmpty) return;

    _cachedSurahsJson ??= await rootBundle.loadString('assets/data/surahs.json');
    final List<dynamic> jsonList = await compute(_parseJson, _cachedSurahsJson!);

    final map = <int, SurahModel>{};
    for (final item in jsonList) {
      final surah = SurahModel(
        id: item['id'] as int,
        name: item['name_ar'] as String,
        englishName: item['name_en'] as String,
        revelationType: item['revelation_type'] as String,
        versesCount: item['ayah_count'] as int,
        pageStart: 1,
        pageEnd: 1,
      );
      map[surah.id] = surah;
    }
    await box.putAll(map);
  }

  static Future<void> _seedVersesAndTafseer() async {
    final versesBox = HiveService.versesBox;
    final tafseerBox = HiveService.tafseerBox;
    final versesDone =
        versesBox.isNotEmpty && tafseerBox.get('_verses_source') == _versesSource;
    final tafseerDone = tafseerBox.get('_source') == 'json_v8';
    if (versesDone && tafseerDone) return;

    final jsonStr = await _loadQuran();
    final jsonList = await compute(_parseJson, jsonStr);

    if (!versesDone) {
      final juzCounts = <int, int>{};
      for (final item in jsonList) {
        final juz = item['juz'] as int;
        juzCounts[juz] = (juzCounts[juz] ?? 0) + 1;
      }

      final juzIndex = <int, int>{};
      final vMap = <int, VerseModel>{};
      for (int i = 0; i < jsonList.length; i++) {
        final item = jsonList[i];
        final juz = item['juz'] as int;
        final idx = (juzIndex[juz] ?? 0) + 1;
        juzIndex[juz] = idx;
        final total = juzCounts[juz]!;
        final hq = ((idx - 1) * 8 ~/ total) + 1;
        vMap[i + 1] = VerseModel(
          id: i + 1,
          surahId: item['surah_id'] as int,
          verseNumber: item['ayah_number'] as int,
          text: QuranTextNormalizer.preProcessForDisplay(item['text_simple'] as String),
          textUthmani: QuranTextNormalizer.preProcessForDisplay(item['text_uthmani'] as String),
          juz: juz,
          page: item['page'] as int,
          hizbQuarter: hq.clamp(1, 8),
        );
      }
      await versesBox.putAll(vMap);
      await tafseerBox.put('_verses_source', _versesSource);
    }

    if (!tafseerDone) {
      if (tafseerBox.isNotEmpty) await tafseerBox.clear();
      final tMap = <String, String>{};
      for (final item in jsonList) {
        var tafseer = item['tafseer'] as String;
        tafseer = tafseer.replaceAll(RegExp(r'<[^>]*>'), '');
        tafseer = tafseer.replaceAll('\uFD60', '');
        tafseer = tafseer.replaceAll('\uFD61', '');
        tafseer = tafseer.replaceAll('\u200A', '');
        tMap['${item['surah_id'] as int}:${item['ayah_number'] as int}'] = tafseer;

        var tafseerEn = item['tafseer_en'] as String? ?? '';
        if (tafseerEn.isNotEmpty) {
          tafseerEn = tafseerEn.replaceAll(RegExp(r'<[^>]*>'), '');
          tMap['en:${item['surah_id'] as int}:${item['ayah_number'] as int}'] = tafseerEn;
        }
      }
      tMap['_source'] = 'json_v8';
      tMap['_verses_source'] = _versesSource;
      await tafseerBox.putAll(tMap);
    }
  }

  static Future<void> _seedTranslations() async {
    final translationBox = HiveService.translationBox;
    if (translationBox.get('_source') == 'v2') return;

    final jsonStr = await _loadQuran();
    final jsonList = await compute(_parseJson, jsonStr);

    if (translationBox.isNotEmpty) await translationBox.clear();
    final tMap = <String, String>{};
    for (final item in jsonList) {
      final key = '${item['surah_id'] as int}:${item['ayah_number'] as int}';
      final trEn = item['translation_en'] as String? ?? '';
      if (trEn.isNotEmpty) tMap['tr_en:$key'] = trEn;
      final trUr = item['translation_ur'] as String? ?? '';
      if (trUr.isNotEmpty) tMap['tr_ur:$key'] = trUr;
    }
    tMap['_source'] = 'v2';
    await translationBox.putAll(tMap);
  }

  static Future<void> _seedReciters() async {
    final box = HiveService.recitersBox;
    final reciters = [
      // Makkah & Madinah Imams
      ReciterModel(
        id: 'mishary',
        name: 'Mishary Rashid Alafasy',
        arabicName: 'مشاري راشد العفاسي',
        bio: 'Kuwaiti reciter and imam',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Alafasy_128kbps',
        isClassical: false,
      ),
      ReciterModel(
        id: 'sudais',
        name: 'Abdul Rahman Al-Sudais',
        arabicName: 'عبد الرحمن السديس',
        bio: 'Imam of Masjid al-Haram',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Abdurrahmaan_As-Sudais_192kbps',
        isClassical: false,
      ),
      ReciterModel(
        id: 'shuraim',
        name: 'Saud Al-Shuraim',
        arabicName: 'سعود الشريم',
        bio: 'Imam of Masjid al-Haram',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Saood_ash-Shuraym_128kbps',
        isClassical: false,
      ),
      ReciterModel(
        id: 'muaiqly',
        name: 'Maher Al-Muaiqly',
        arabicName: 'ماهر المعيقلي',
        bio: 'Imam and reciter',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/MaherAlMuaiqly128kbps',
        isClassical: false,
      ),
      ReciterModel(
        id: 'dosari',
        name: 'Yasser Al-Dosari',
        arabicName: 'ياسر الدوسري',
        bio: 'Saudi reciter and imam',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Yasser_Ad-Dussary_128kbps',
        isClassical: false,
      ),
      ReciterModel(
        id: 'ajmi',
        name: 'Ahmed ibn Ali Al-Ajmi',
        arabicName: 'أحمد بن علي العجمي',
        bio: 'Saudi reciter',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net',
        isClassical: false,
      ),
      ReciterModel(
        id: 'ghamdi',
        name: 'Saad Al-Ghamdi',
        arabicName: 'سعد الغامدي',
        bio: 'Saudi reciter',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Ghamadi_40kbps',
        isClassical: false,
      ),
      ReciterModel(
        id: 'huthaify',
        name: 'Ali Al-Huthaify',
        arabicName: 'علي الحذيفي',
        bio: 'Imam of Masjid an-Nabawi',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Hudhaify_128kbps',
        isClassical: false,
      ),
      // Classic Egyptian Reciters
      ReciterModel(
        id: 'abdulbasit',
        name: 'Abdul Basit Abdul Samad',
        arabicName: 'عبد الباسط عبد الصمد',
        bio: 'Legendary Egyptian reciter',
        imageAsset: '',
        category: 'Classic Egyptian Reciters',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Abdul_Basit_Murattal_64kbps',
        isClassical: true,
      ),
      ReciterModel(
        id: 'husary',
        name: 'Mahmoud Khalil Al-Husary',
        arabicName: 'محمود خليل الحصري',
        bio: 'Renowned Egyptian reciter',
        imageAsset: '',
        category: 'Classic Egyptian Reciters',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Husary_128kbps',
        isClassical: true,
      ),
      ReciterModel(
        id: 'minshawi',
        name: 'Mohamed Siddiq El-Minshawi',
        arabicName: 'محمد صديق المنشاوي',
        bio: 'Renowned Egyptian reciter',
        imageAsset: '',
        category: 'Classic Egyptian Reciters',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/Minshawy_Murattal_128kbps',
        isClassical: true,
      ),
      ReciterModel(
        id: 'banna',
        name: 'Mahmoud Ali Al-Banna',
        arabicName: 'محمود علي البنا',
        bio: 'Egyptian reciter',
        imageAsset: '',
        category: 'Classic Egyptian Reciters',
        audioBaseUrl: 'https://mirrors.quranicaudio.com/everyayah/data/mahmoud_ali_al_banna_32kbps',
        isClassical: true,
      ),
      ReciterModel(
        id: 'shatri',
        name: 'Abu Bakr Ash-Shatri',
        arabicName: 'أبو بكر الشاطري',
        bio: 'Former imam of the Grand Mosque in Makkah',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: '',
        isClassical: false,
      ),
      ReciterModel(
        id: 'qasim',
        name: 'Abdul Mohsen Al-Qasim',
        arabicName: 'عبد المحسن القاسم',
        bio: 'Imam and khatib of the Prophet\'s Mosque in Madinah',
        imageAsset: '',
        category: 'Makkah & Madinah Imams',
        audioBaseUrl: '',
        isClassical: false,
      ),
      ReciterModel(
        id: 'rifai',
        name: 'Hani Ar-Rifai',
        arabicName: 'هاني الرفاعي',
        bio: 'Egyptian qari, celebrated for his clear and powerful recitation',
        imageAsset: '',
        category: 'Classic Egyptian Reciters',
        audioBaseUrl: '',
        isClassical: false,
      ),
      ReciterModel(
        id: 'tunaiji',
        name: 'Khalifa Al-Tunaiji',
        arabicName: 'خليفة الطنيجي',
        bio: 'Qatari imam and qari, renowned for his melodious recitation',
        imageAsset: '',
        category: 'International Reciters',
        audioBaseUrl: '',
        isClassical: false,
      ),
      ReciterModel(
        id: 'fares',
        name: 'Fares Abbad',
        arabicName: 'فارس عباد',
        bio: 'Yemeni qari known for his fast yet precise recitation',
        imageAsset: '',
        category: 'Hadr / Fast Recitation',
        audioBaseUrl: '',
        isClassical: false,
      ),
    ];

    await box.clear();
    final map = <String, ReciterModel>{};
    for (final reciter in reciters) {
      map[reciter.id] = reciter;
    }
    await box.putAll(map);
  }
}

List<dynamic> _parseJson(String jsonStr) {
  return json.decode(jsonStr) as List<dynamic>;
}