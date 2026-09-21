import 'dart:math';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes an ayah of the week to the home screen ayah widget.
class AyahWidgetService {
  AyahWidgetService._();
  static const _widgetName = 'AyahWidgetProvider';

  static const _ayahs = [
    {'text': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ', 'surah': 'الفاتحة', 'number': '1'},
    {'text': 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ', 'surah': 'الفاتحة', 'number': '2'},
    {'text': 'ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ', 'surah': 'الفاتحة', 'number': '3'},
    {'text': 'مَـٰلِكِ يَوْمِ ٱلدِّينِ', 'surah': 'الفاتحة', 'number': '4'},
    {'text': 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ', 'surah': 'الفاتحة', 'number': '5'},
    {'text': 'ٱهْدِنَا ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ', 'surah': 'الفاتحة', 'number': '6'},
    {'text': 'صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ', 'surah': 'الفاتحة', 'number': '7'},
    {'text': 'إِنَّ ٱللَّهَ عَلَىٰ كُلِّ شَىْءٍ قَدِيرٌ', 'surah': 'البقرة', 'number': '20'},
    {'text': 'وَمَآ أَرْسَلْنَـٰكَ إِلَّا رَحْمَةً لِّلْعَـٰلَمِينَ', 'surah': 'الأنبياء', 'number': '107'},
    {'text': 'وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ', 'surah': 'الضحى', 'number': '5'},
    {'text': 'وَإِلَٰهُكُمْ إِلَٰهٌ وَٰحِدٌ ۖ لَّآ إِلَٰهَ إِلَّا هُوَ ٱلرَّحْمَـٰنُ ٱلرَّحِيمُ', 'surah': 'البقرة', 'number': '163'},
    {'text': 'وَإِن تَعُدُّوا۟ نِعْمَةَ ٱللَّهِ لَا تُحْصُوهَآ', 'surah': 'إبراهيم', 'number': '34'},
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
