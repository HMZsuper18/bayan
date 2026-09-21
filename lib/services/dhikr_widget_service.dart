import 'dart:math';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes random azkar to the home screen dhikr widget.
class DhikrWidgetService {
  DhikrWidgetService._();
  static const _widgetName = 'DhikrWidgetProvider';

  static const _azkar = [
    {'text': 'سُبْحَانَ ٱللَّهِ', 'count': '33'},
    {'text': 'ٱلْحَمْدُ لِلَّهِ', 'count': '33'},
    {'text': 'ٱللَّهُ أَكْبَرُ', 'count': '34'},
    {'text': 'لَا إِلَٰهَ إِلَّا ٱللَّهُ', 'count': '100'},
    {'text': 'أَسْتَغْفِرُ ٱللَّهَ', 'count': '100'},
    {'text': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللَّهِ', 'count': '100'},
    {'text': 'سُبْحَانَ ٱللَّهِ وَبِحَمْدِهِ', 'count': '100'},
    {'text': 'سُبْحَانَ ٱللَّهِ ٱلْعَظِيمِ', 'count': '100'},
    {'text': 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ', 'count': '100'},
    {'text': 'لَا إِلَٰهَ إِلَّا ٱللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ', 'count': '100'},
  ];

  static Future<void> update() async {
    try {
      final azkar = _azkar[Random().nextInt(_azkar.length)];
      await HomeWidget.saveWidgetData('dhikr_text', azkar['text']);
      await HomeWidget.saveWidgetData('dhikr_count', azkar['count']);
      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget not available on desktop.
    }
  }

  static Future<void> refresh() async {
    await update();
  }
}
