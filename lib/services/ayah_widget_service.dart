import 'dart:math';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes a meaningful ayah to the home screen ayah widget.
class AyahWidgetService {
  AyahWidgetService._();
  static const _widgetName = 'AyahWidgetProvider';

  static const _ayahs = [
    {'text': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', 'surah': 'الفاتحة', 'number': '1'},
    {'text': 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ', 'surah': 'الفاتحة', 'number': '2'},
    {'text': 'ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', 'surah': 'الفاتحة', 'number': '3'},
    {'text': 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ', 'surah': 'الفاتحة', 'number': '5'},
    {'text': 'ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ', 'surah': 'الفاتحة', 'number': '6'},
    {'text': 'إِنَّ ٱللَّهَ عَلَىٰ كُلِّ شَىْءٍ قَدِيرٌ', 'surah': 'البقرة', 'number': '20'},
    {'text': 'وَمَآ أَرْسَلْنَٰكَ إِلَّا رَحْمَةً لِّلْعَٰلَمِينَ', 'surah': 'الأنبياء', 'number': '107'},
    {'text': 'وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ', 'surah': 'الضحى', 'number': '5'},
    {'text': 'وَإِن تَعُدُّوا۟ نِعْمَةَ ٱللَّهِ لَا تُحْصُوهَآ', 'surah': 'إبراهيم', 'number': '34'},
    {'text': 'رَبَّنَا ظَلَمْنَآ أَنفُسَنَا وَإِن لَّمْ تَغْفِرْ لَنَا وَتَرْحَمْنَا لَنَكُونَنَّ مِنَ ٱلْخَٰسِرِينَ', 'surah': 'الأعراف', 'number': '23'},
    {'text': 'رَبَّنَا آتِنَا فِى ٱلدُّنْيَا حَسَنَةً وَفِى ٱلْءَاخِرَةِ حَسَنَةً وَقِنَا عَذَابَ ٱلنَّارِ', 'surah': 'البقرة', 'number': '201'},
    {'text': 'وَقُل رَّبِّ زِدْنِى عِلْمًا', 'surah': 'طه', 'number': '114'},
    {'text': 'فَبِأَىِّ ءَالَآءِ رَبِّكُمَا تُكَذِّبَانِ', 'surah': 'الرحمن', 'number': '13'},
    {'text': 'إِنَّ مَعَ ٱلْعُسْرِ يُسْرًا', 'surah': 'الشرح', 'number': '6'},
    {'text': 'لَا يُكَلِّفُ ٱللَّهُ نَفْسًا إِلَّا وُسْعَهَا', 'surah': 'البقرة', 'number': '286'},
    {'text': 'وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ', 'surah': 'الضحى', 'number': '5'},
    {'text': 'وَإِلَٰهُكُمْ إِلَٰهٌ وَٰحِدٌ ۖ لَّآ إِلَٰهَ إِلَّا هُوَ ٱلرَّحْمَٰنُ ٱلرَّحِيمُ', 'surah': 'البقرة', 'number': '163'},
    {'text': 'إِنَّ ٱللَّهَ يُحِبُّ ٱلتَّوَّابِينَ وَيُحِبُّ ٱلْمُتَطَهِّرِينَ', 'surah': 'البقرة', 'number': '222'},
    {'text': 'وَلَا تَيْأَسُوا۟ مِن رَّوْحِ ٱللَّهِ', 'surah': 'يوسف', 'number': '87'},
    {'text': 'وَتَعَاوَنُوا۟ عَلَى ٱلْبِرِّ وَٱلتَّقْوَىٰ', 'surah': 'المائدة', 'number': '2'},
  ];

  static Future<void> update() async {
    try {
      final ayah = _ayahs[Random().nextInt(_ayahs.length)];
      await HomeWidget.saveWidgetData('ayah_text', ayah['text']);
      await HomeWidget.saveWidgetData('ayah_surah', ayah['surah']);
      await HomeWidget.saveWidgetData('ayah_number', ayah['number']);
      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget not available on desktop.
    }
  }

  static Future<void> refresh() async {
    await update();
  }
}
