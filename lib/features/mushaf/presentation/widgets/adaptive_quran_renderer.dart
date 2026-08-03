import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:bayan/core/utils/quran_render_config.dart';
import 'package:bayan/core/utils/quran_text_normalizer.dart';
import '../../../../data/models/verse_model.dart';
import 'mushaf_text_renderer.dart';

enum QuranDisplayMode { surahView, pageView }

class AdaptiveQuranRenderer extends StatelessWidget {
  final QuranDisplayMode displayMode;
  final int surahId;
  final int? pageNumber;
  final List<VerseModel> verses;
  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final VerseModel? selectedVerse;
  final int? playingVerseNumber;
  final void Function(VerseModel) onVerseTap;
  final ColorScheme colors;
  final List<String?>? translations;

  const AdaptiveQuranRenderer({
    super.key,
    required this.displayMode,
    required this.surahId,
    required this.verses,
    required this.fontSize,
    required this.onVerseTap,
    required this.colors,
    this.pageNumber,
    this.selectedVerse,
    this.playingVerseNumber,
    this.lineHeight = 2.2,
    this.horizontalPadding = 32.0,
    this.translations,
  });

  bool get _hasTranslations =>
      translations != null && translations!.any((t) => t != null && t.isNotEmpty);

  bool get _useSpecialLayout {
    if (_hasTranslations) return false;
    if (displayMode == QuranDisplayMode.surahView) {
      return surahId == 1;
    }
    return pageNumber != null && pageNumber! <= 2;
  }

  int get _specialPageKey {
    if (displayMode == QuranDisplayMode.surahView) return 1;
    return pageNumber ?? 1;
  }

  List<String> _getSpecialLines() {
    return _specialPageKey == 1 ? _page1Lines : _page2Lines;
  }

  static const _page1Lines = [
    'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ ١ ٱلرَّحْمَـٰنِ',
    'ٱلرَّحِيمِ ٢ مَـٰلِكِ يَوْمِ ٱلدِّينِ ٣ إِيَّاكَ',
    'نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ ٤ ٱهْدِنَا',
    'ٱلصِّرَٰطَ ٱلْمُسْتَقِيمَ ٥ صِرَٰطَ ٱلَّذِينَ',
    'أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ',
    'عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ ٦',
  ];

  static const _page2Lines = [
    'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    'الٓمٓ ١ ذَٰلِكَ ٱلْكِتَـٰبُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى',
    'لِّلْمُتَّقِينَ ٢ ٱلَّذِينَ يُؤْمِنُونَ بِٱلْغَيْبِ',
    'وَيُقِيمُونَ ٱلصَّلَوٰةَ وَمِمَّا رَزَقْنَـٰهُمْ يُنفِقُونَ ٣',
    'وَٱلَّذِينَ يُؤْمِنُونَ بِمَآ أُنزِلَ إِلَيْكَ وَمَآ أُنزِلَ',
    'مِن قَبْلِكَ وَبِٱلْـَٔاخِرَةِ هُمْ يُوقِنُونَ ٤',
    'أُو۟لَـٰٓئِكَ عَلَىٰ هُدًى مِّن رَّبِّهِمْ ۖ وَأُو۟لَـٰٓئِكَ هُمُ ٱلْمُفْلِحُونَ ٥',
  ];

  @override
  Widget build(BuildContext context) {
    final body = _useSpecialLayout
        ? _buildSpecialLayout()
        : MushafTextRenderer(
            verses: verses,
            surahId: surahId,
            fontSize: fontSize,
            lineHeight: lineHeight,
            horizontalPadding: horizontalPadding,
            onVerseTap: onVerseTap,
            colors: colors,
            selectedVerse: selectedVerse,
            playingVerseNumber: playingVerseNumber,
            translations: translations,
          );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDivider(120, 0.25),
          body,
          _buildDivider(80, 0.15),
        ],
      ),
    );
  }

  static const _basmalahText =
      'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

  /// The special-page lines go through [QuranTextNormalizer.preProcessForDisplay]
  /// (which strips U+0670 and reorders marks), so the comparison target must be
  /// normalized the same way, otherwise the basmalah would be misclassified as
  /// a regular verse span.
  static final String _normalizedBasmalahText =
      QuranTextNormalizer.preProcessForDisplay(_basmalahText);

  static final _markerPattern = RegExp(r'[\u0660-\u0669]+');

  List<List<_SpanInfo>> _buildLineSpans() {
    final lines = _getSpecialLines();

    // The special page layout always opens with the basmalah on line 0. The
    // basmalah is a decorative header, not a verse: it must never be tappable
    // or selectable. The remaining lines reproduce the surah's real verses.
    // Each Arabic-Indic number marker sits at the *end* of its ayah, so the
    // marker and the text before it belong to the same verse while the text
    // that follows starts the next verse. We walk the spans in that order and
    // map each one to the correct [VerseModel] (instead of a blind global
    // counter).
    //
    // The special layout is only ever built for page 1 / surah 1 (whose
    // bundled data still contains the basmalah as verse 1:1, so the visual
    // verses start at data index 1) or page 2 / surah 2 (no bundled basmalah,
    // visual verses start at data index 0).
    final basmalahOffset = _specialPageKey == 1 ? 1 : 0;

    final result = <List<_SpanInfo>>[];
    var currentVerse = -1; // -1 while inside the basmalah header.
    var awaitingNewVerse = false; // Set when a marker closed the previous verse.

    void addTextSpan(List<_SpanInfo> spans, String text, bool isFirstLine) {
      if (text.trim().isEmpty) return;
      if (isFirstLine) {
        spans.add(_SpanInfo(text, -1));
        awaitingNewVerse = false;
        return;
      }
      if (currentVerse < 0 || awaitingNewVerse) {
        currentVerse++;
      }
      awaitingNewVerse = false;
      final verseIndex = currentVerse + basmalahOffset;
      spans.add(_SpanInfo(text, verseIndex < verses.length ? verseIndex : -1));
    }

    for (int li = 0; li < lines.length; li++) {
      final line = QuranTextNormalizer.preProcessForDisplay(lines[li]);
      final spans = <_SpanInfo>[];
      final matches = _markerPattern.allMatches(line).toList();
      int lastEnd = 0;

      for (final m in matches) {
        if (m.start > lastEnd) {
          addTextSpan(spans, line.substring(lastEnd, m.start), li == 0);
        }
        final markerVerse = currentVerse < 0 ? -1 : currentVerse + basmalahOffset;
        spans.add(_SpanInfo(m.group(0)!, markerVerse));
        awaitingNewVerse = true;
        lastEnd = m.end;
      }

      if (lastEnd < line.length) {
        addTextSpan(spans, line.substring(lastEnd), li == 0);
      }

      if (spans.isEmpty) {
        spans.add(_SpanInfo(line, -1));
      }

      result.add(spans);
    }

    return result;
  }

  Widget _buildSpecialLayout() {
    final lineSpans = _buildLineSpans();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < lineSpans.length; i++)
              _buildArchLine(lineSpans[i], i),
          ],
        ),
      ),
    );
  }

  Widget _buildArchLine(List<_SpanInfo> spans, int lineIndex) {
    final taperPadding = _taperForLine(lineIndex);
    final isEven = lineIndex.isEven;
    final lineColor = isEven
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: 0.92);

    final textSpans = <InlineSpan>[];
    for (final span in spans) {
      final verse = span.idx >= 0 && span.idx < verses.length
          ? verses[span.idx]
          : null;
      final isHighlighted =
          verse != null && selectedVerse?.id == verse.id;

      final baseStyle = TextStyle(
        fontFamily: QuranRenderConfig.fontFamily,
        fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
        fontSize: fontSize,
        height: lineHeight,
        color: lineColor,
        wordSpacing: 0,
        letterSpacing: 0,
        fontFeatures: QuranRenderConfig.openTypeFeatures,
      );

      // End-of-ayah number markers render in the Uthmanic font, matching the
      // printed mushaf's ayah ornaments.
      final isVerseNumber = _markerPattern.hasMatch(span.text.trim());
      final spanStyle = isVerseNumber
          ? baseStyle.copyWith(
              fontFamily: QuranRenderConfig.verseNumberFontFamily,
              fontFamilyFallback:
                  QuranRenderConfig.verseNumberFontFamilyFallback,
            )
          : baseStyle;

      final isBasmalah = span.text.trim() == _normalizedBasmalahText;

      if (verse == null || isBasmalah) {
        textSpans.add(TextSpan(text: span.text, style: spanStyle));
      } else {
        textSpans.add(TextSpan(
          text: span.text,
          style: spanStyle.copyWith(
            backgroundColor: isHighlighted
                ? colors.primaryContainer.withValues(alpha: 0.4)
                : null,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => onVerseTap(verse),
        ));
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: taperPadding, vertical: 1),
      child: Text.rich(
        TextSpan(children: textSpans),
        textAlign: TextAlign.center,
      ),
    );
  }

  double _taperForLine(int index) {
    const taperMap = {0: 48.0, 1: 20.0, 2: 8.0, 3: 4.0, 4: 8.0, 5: 20.0, 6: 48.0};
    return taperMap[index] ?? 24.0;
  }

  Widget _buildDivider(double width, double opacity) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          height: 2,
          width: width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.onSurface.withValues(alpha: 0),
                colors.onSurface.withValues(alpha: opacity),
                colors.onSurface.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpanInfo {
  final String text;
  final int idx;
  const _SpanInfo(this.text, this.idx);
}
