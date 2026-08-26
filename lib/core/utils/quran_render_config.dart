import 'package:flutter/material.dart';

class QuranRenderConfig {
  /// Primary Quran font. Amiri Quran renders the Quranic marks (silah U+06DF,
  /// waqf U+06D6, etc.) at their authentic small size — matching the printed
  /// Madani mushaf — and covers every codepoint in quran.json (71/71,
  /// including U+25CC).
  static const fontFamily = 'AmiriQuran';

  /// Fallback chain so no glyph can ever tofu. KFGQPC Uthmanic Hafs covers
  /// all 71 codepoints too, so this is a pure safety net.
  static const fontFamilyFallback = <String>['Uthmanic'];

  /// For UI text styled with Tajawal (e.g. search tiles) that may embed Quran
  /// text: fall back to Amiri FIRST so the Quranic marks stay small and
  /// authentic (Uthmanic would draw them as oversized circles).
  static const fontFamilyFallbackForUi = <String>[fontFamily, ...fontFamilyFallback];

  /// Font for the end-of-ayah number markers (e.g. ٥ after each verse),
  /// matching the printed mushaf's ayah-number ornaments. KFGQPC Uthmanic
  /// covers the Arabic-Indic digits U+0660–U+0669 natively.
  static const verseNumberFontFamily = 'Uthmanic';

  /// Safety net for the verse-number font (falls back to Amiri if a digit is
  /// ever missing).
  static const verseNumberFontFamilyFallback = <String>['AmiriQuran'];

  static const openTypeFeatures = <FontFeature>[
    FontFeature('mark', 1),
    FontFeature('mkmk', 1),
    FontFeature('rlig', 1),
    FontFeature('liga', 1),
    FontFeature('calt', 1),
    FontFeature('curs', 1),
    FontFeature('kern', 1),
    FontFeature('dlig', 0),
  ];

  static const textScaler = TextScaler.linear(1.0);

  static TextStyle quranStyle({
    required double fontSize,
    required Color color,
    Color? background,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      height: 2.0,
      color: color,
      backgroundColor: background,
      fontFeatures: openTypeFeatures,
    );
  }

  static MediaQueryData textScalingDisabled(BuildContext context) {
    return MediaQuery.of(context).copyWith(textScaler: textScaler);
  }

  static Widget rtl(Widget child) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: child,
    );
  }

  static Widget ltr(Widget child) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    );
  }
}
