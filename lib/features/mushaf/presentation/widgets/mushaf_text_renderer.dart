import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:bayan/core/utils/quran_render_config.dart';
import 'package:bayan/core/utils/quran_text_normalizer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/verse_model.dart';

class MushafTextRenderer extends StatelessWidget {
  final List<VerseModel> verses;
  final int surahId;
  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final VerseModel? selectedVerse;
  final int? playingSurahId;
  final int? playingVerseNumber;
  final void Function(VerseModel) onVerseTap;
  final ColorScheme colors;
  final bool showBasmalah;
  final List<String?>? translations;

  const MushafTextRenderer({
    super.key,
    required this.verses,
    required this.surahId,
    required this.fontSize,
    required this.onVerseTap,
    required this.colors,
    this.selectedVerse,
    this.playingSurahId,
    this.playingVerseNumber,
    this.showBasmalah = true,
    this.lineHeight = 2.2,
    this.horizontalPadding = 32.0,
    this.translations,
  });

  static const _basmalah =
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

  static const _arabicDigits = [
    '\u0660', '\u0661', '\u0662', '\u0663', '\u0664',
    '\u0665', '\u0666', '\u0667', '\u0668', '\u0669',
  ];

  static String _arabicIndic(int n) {
    if (n == 0) return _arabicDigits[0];
    String result = '';
    while (n > 0) {
      result = _arabicDigits[n % 10] + result;
      n ~/= 10;
    }
    return result;
  }

  /// Al-Fatiha is the only surah whose basmalah is itself verse 1:1 (numbered ١
  /// in the printed mushaf), so it renders like any other verse. For all other
  /// surahs (except At-Tawbah, which has none) the basmalah is an unnumbered
  /// opening header drawn by [_buildBasmalah].
  bool get _shouldShowBasmalah =>
      showBasmalah &&
      surahId != 1 &&
      surahId != 9 &&
      verses.isNotEmpty &&
      verses.first.verseNumber == 1;

  int _displayNumber(VerseModel verse) => verse.verseNumber;

  TextStyle _verseStyle(Color color, Color? background) {
    return TextStyle(
      fontFamily: QuranRenderConfig.fontFamily,
      fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
      fontSize: fontSize,
      height: lineHeight,
      color: color,
      backgroundColor: background,
      wordSpacing: 0,
      letterSpacing: 0,
      fontFeatures: QuranRenderConfig.openTypeFeatures,
    );
  }

  /// The end-of-ayah number marker uses the Uthmanic font (matching the
  /// printed mushaf's ayah ornaments) while the verse text stays in Amiri.
  TextStyle _verseNumberStyle(Color color, Color? background) {
    return _verseStyle(color, background).copyWith(
      fontFamily: QuranRenderConfig.verseNumberFontFamily,
      fontFamilyFallback: QuranRenderConfig.verseNumberFontFamilyFallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_shouldShowBasmalah) _buildBasmalah(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  bool get _hasTranslations =>
      translations != null && translations!.any((t) => t != null && t.isNotEmpty);

  Widget _buildBasmalah() {
    return Padding(
      padding: EdgeInsets.only(bottom: 28),
      child: Text(
        _basmalah,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: QuranRenderConfig.fontFamily,
          fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
          fontSize: fontSize,
          height: lineHeight,
          color: colors.onSurface.withValues(alpha: 0.85),
          wordSpacing: 0,
          letterSpacing: 0,
          fontFeatures: QuranRenderConfig.openTypeFeatures,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_hasTranslations) {
      return _buildVerseParagraph();
    }
    return _buildVersesWithTranslation();
  }

  Widget _buildVerseParagraph() {
    final spans = <InlineSpan>[];

    for (final verse in verses) {
      final isSelected = selectedVerse?.id == verse.id;
      final isPlaying = playingVerseNumber == verse.verseNumber &&
          (playingSurahId == null || playingSurahId == surahId);

      Color? bgColor;
      if (isSelected) {
        bgColor = colors.primaryContainer.withValues(alpha: 0.4);
      } else if (isPlaying) {
        bgColor = AppColors.playingVerseHighlight;
      }

      final verseText =
          QuranTextNormalizer.preProcessForDisplay(verse.textUthmani).trimRight();
      final verseStyle = _verseStyle(colors.onSurface, bgColor);

      spans.add(
        TextSpan(
          text: verseText,
          style: verseStyle,
          recognizer: TapGestureRecognizer()..onTap = () => onVerseTap(verse),
        ),
      );

      final ayahNumber = _arabicIndic(_displayNumber(verse));
      spans.add(
        TextSpan(
          text: ' $ayahNumber ',
          style: _verseNumberStyle(colors.onSurface, bgColor),
          recognizer: TapGestureRecognizer()..onTap = () => onVerseTap(verse),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
    );
  }

  Widget _buildVersesWithTranslation() {
    final rows = <Widget>[];
    var added = 0;
    for (int i = 0; i < verses.length; i++) {
      if (added > 0) rows.add(const SizedBox(height: 12));
      rows.add(_buildVerseBlock(verses[i], translations![i]));
      added++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _buildVerseBlock(VerseModel verse, String? translation) {
    final isSelected = selectedVerse?.id == verse.id;
    final isPlaying = playingVerseNumber == verse.verseNumber &&
        (playingSurahId == null || playingSurahId == surahId);

    Color? bgColor;
    if (isSelected) {
      bgColor = colors.primaryContainer.withValues(alpha: 0.4);
    } else if (isPlaying) {
      bgColor = AppColors.playingVerseHighlight;
    }

    final verseText =
        QuranTextNormalizer.preProcessForDisplay(verse.textUthmani).trimRight();
    final verseStyle = _verseStyle(colors.onSurface, bgColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: verseText,
                style: verseStyle,
                recognizer: TapGestureRecognizer()..onTap = () => onVerseTap(verse),
              ),
              TextSpan(
                text: ' ${_arabicIndic(_displayNumber(verse))} ',
                style: _verseNumberStyle(colors.onSurface, bgColor),
                recognizer: TapGestureRecognizer()..onTap = () => onVerseTap(verse),
              ),
            ],
          ),
          textAlign: TextAlign.justify,
        ),
        if (translation != null && translation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                translation,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: fontSize * 0.6,
                  height: 1.4,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
