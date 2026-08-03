import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/quran_render_config.dart';
import '../../../../core/utils/quran_text_normalizer.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../data/models/surah_model.dart';
import '../../../../data/models/verse_model.dart';
import '../../../../l10n/app_localizations.dart';

/// Bottom sheet that renders the shareable Ayah-of-the-Week poster image,
/// lets the user preview it, and shares it via the system share sheet.
class AyahOfWeekShareSheet extends StatefulWidget {
  final VerseModel verse;
  final SurahModel surah;

  const AyahOfWeekShareSheet({
    super.key,
    required this.verse,
    required this.surah,
  });

  @override
  State<AyahOfWeekShareSheet> createState() => _AyahOfWeekShareSheetState();
}

class _AyahOfWeekShareSheetState extends State<AyahOfWeekShareSheet> {
  final _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              byteData.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'ayah_of_the_week.png',
            ),
          ],
          text: l10n.ayahOfTheWeekAd,
        ),
      );
    } catch (e) {
      debugPrint('Share failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.unknownError)));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBody = FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: GlassConfig.enableBlur
              ? (isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.25))
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _DragHandle(),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n.ayahOfTheWeek,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Center(
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    // The poster's height adapts to the ayah length, so the
                    // captured image always contains the full verse — long
                    // ayahs are never clipped. The scroll view here is only for
                    // previewing a tall poster on screen.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width =
                            constraints.maxWidth <
                                AyahOfWeekPoster.posterWidth
                            ? constraints.maxWidth
                            : AyahOfWeekPoster.posterWidth;
                        return AyahOfWeekPoster(
                          verse: widget.verse,
                          surah: widget.surah,
                          width: width,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _sharing ? null : _share,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _sharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded, size: 20),
                  label: Text(
                    _sharing ? l10n.processing : l10n.shareAyah,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: GlassConfig.enableBlur
          ? BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: sheetBody,
            )
          : sheetBody,
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// The shareable poster: fixed logical width (rendered at 3x for a crisp
/// image) with a height that grows to fit the ayah, so the full verse is
/// always captured. Contains the verse, surah reference, app name and the
/// localized ad line.
class AyahOfWeekPoster extends StatelessWidget {
  final VerseModel verse;
  final SurahModel surah;

  /// Optional override for narrow screens; defaults to [posterWidth].
  final double width;

  const AyahOfWeekPoster({
    super.key,
    required this.verse,
    required this.surah,
    this.width = posterWidth,
  });

  static const double posterWidth = 360;

  static String _arabicIndic(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }

  /// Long ayahs get a slightly smaller verse font so the poster stays
  /// reasonably proportioned while remaining fully readable.
  double _verseFontSize(String text) {
    if (text.length > 400) return 18;
    if (text.length > 200) return 21;
    return 24;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final verseText = QuranTextNormalizer.preProcessForDisplay(
      verse.textUthmani,
    );
    final verseFontSize = _verseFontSize(verseText);

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B2E), Color(0xFF00674F), Color(0xFF008A6A)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x66FFD9A0), width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Brand row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Color(0xFFFFD9A0),
                ),
                const SizedBox(width: 8),
                Text(
                  'Bayan',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: const Color(0xFFFFD9A0),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Color(0xFFFFD9A0),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ayahOfTheWeek,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 1.4,
              width: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFFFFD9A0).withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            // Verse — wraps naturally, growing the poster so nothing is cut.
            Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  verseText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: QuranRenderConfig.fontFamily,
                    fontFamilyFallback:
                        QuranRenderConfig.fontFamilyFallback,
                    fontSize: verseFontSize,
                    height: 1.95,
                    color: const Color(0xFFFDFBF7),
                    fontFeatures: QuranRenderConfig.openTypeFeatures,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Surah reference
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'سُورَة ${surah.name} — ${_arabicIndic(verse.verseNumber)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFD9A0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Ad line
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Text(
                l10n.ayahOfTheWeekAd,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
