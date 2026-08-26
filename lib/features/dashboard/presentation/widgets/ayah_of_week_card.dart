import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/quran_render_config.dart';
import '../../../../core/utils/quran_text_normalizer.dart';
import '../../../../data/database/hive_service.dart';
import '../../../../data/database/settings_service.dart';
import '../../../../data/models/surah_model.dart';
import '../../../../data/models/verse_model.dart';
import '../../../../data/repositories/quran_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/ayah_of_week_service.dart';
import '../../../mushaf/presentation/mushaf_navigation.dart';
import 'ayah_of_week_share.dart';

/// SECTION 4 — Merged content card. "Ayah of the Week" at the top and an
/// embeddable footer ([footer]) at the bottom, separated by a soft divider so
/// the card reads as one calm, whitespace-driven surface instead of several
/// nested boxes. The verse is selected deterministically (same for every user
/// worldwide) by [AyahOfWeekService]; tapping the verse part opens the mushaf
/// at that verse.
class AyahOfWeekCard extends StatefulWidget {
  final Widget? footer;

  const AyahOfWeekCard({super.key, this.footer});

  @override
  State<AyahOfWeekCard> createState() => _AyahOfWeekCardState();
}

class _AyahOfWeekCardState extends State<AyahOfWeekCard> {
  Timer? _weekRolloverTimer;
  final _repository = QuranRepository();

  @override
  void initState() {
    super.initState();
    _scheduleWeekRollover();
  }

  void _scheduleWeekRollover() {
    _weekRolloverTimer?.cancel();
    _weekRolloverTimer = Timer(AyahOfWeekService.timeUntilNextWeek, () {
      if (!mounted) return;
      setState(() {});
      _scheduleWeekRollover();
    });
  }

  @override
  void dispose() {
    _weekRolloverTimer?.cancel();
    super.dispose();
  }

  void _openInMushaf(VerseModel verse) {
    MushafNavigation.open(
      context,
      MushafNavigation.forVerse(
        surahId: verse.surahId,
        verseNumber: verse.verseNumber,
        page: verse.page,
        verseId: verse.id,
        openTafseerForVerseId: verse.id,
      ),
    );
  }

  Future<void> _openShareSheet(VerseModel verse, SurahModel surah) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AyahOfWeekShareSheet(verse: verse, surah: surah),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Bright mint keeps the verse reference and the CTA legible on the dark
    // card; primaryGreen gives the light surface enough contrast too.
    final accent = isDark ? const Color(0xFF8FE3C4) : AppColors.primaryGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - t)),
              child: child,
            ),
          );
        },
        child: _buildCardContent(context, l10n, colors, accent),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
    Color accent,
  ) {
    // Rebuild as soon as the verses box is seeded (Hive fills it asynchronously
    // after app start), so the placeholder never sticks.
    return StreamBuilder<BoxEvent>(
      stream: HiveService.versesBox.watch(),
      builder: (context, _) {
        final verse = AyahOfWeekService.verse;
        final surah = verse == null
            ? null
            : HiveService.surahsBox.get(verse.surahId);
        if (verse == null || surah == null) {
          return _GlassCardBody(
            accent: accent,
            child: SizedBox(
              height: 96,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
          );
        }
        return _buildVerseBody(context, l10n, colors, accent, verse, surah);
      },
    );
  }

  Widget _buildVerseBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
    Color accent,
    VerseModel verse,
    SurahModel surah,
  ) {
    final trLang = SettingsService.translationLanguage;
    final translation = trLang != 'ar'
        ? _repository.getTranslation(
            '${verse.surahId}:${verse.verseNumber}',
            language: trLang,
          )
        : null;
    final surahName = switch (trLang) {
      'en' => surah.englishName,
      _ => surah.name,
    };
    final verseText = QuranTextNormalizer.preProcessForDisplay(
      verse.textUthmani,
    );

    return _GlassCardBody(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openInMushaf(verse),
              borderRadius: BorderRadius.circular(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Header row
              Row(
                children: [
                  _StaticOrnament(accent: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.ayahOfTheWeek,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  _WeekChip(label: AyahOfWeekService.weekLabel),
                  const SizedBox(width: 6),
                  // Innermost gesture wins the arena, so the share button does
                  // not trigger the card's mushaf navigation.
                  _ShareButton(onPressed: () => _openShareSheet(verse, surah)),
                ],
              ),
              const SizedBox(height: 14),

              // Verse text (animated on rollover)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Directionality(
                  key: ValueKey('aow_${verse.id}'),
                  textDirection: TextDirection.rtl,
                  child: Text(
                    verseText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: QuranRenderConfig.fontFamily,
                      fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
                      fontSize: 21,
                      height: 1.9,
                      color: colors.onSurface,
                      fontFeatures: QuranRenderConfig.openTypeFeatures,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Surah + ayah reference
              Directionality(
                textDirection: trLang == 'en'
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                child: Text(
                  trLang == 'en'
                      ? '$surahName ${verse.verseNumber}'
                      : '${l10n.surah} $surahName — ${_arabicIndic(verse.verseNumber)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),

              if (translation != null && translation.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Directionality(
                  textDirection: trLang == 'en'
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  child: Text(
                    translation,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      color: colors.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      if (widget.footer != null) ...[
        const SizedBox(height: 12),
        Divider(
          height: 1,
          color: colors.onSurface.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 14),
        widget.footer!,
      ],
    ],
  ),
);
  }

  static String _arabicIndic(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }
}

/// The clean surface of the merged card (respects light/dark + blur settings)
/// with a subtle border instead of a loud gradient frame.
class _GlassCardBody extends StatelessWidget {
  final Widget child;
  final Color accent;

  const _GlassCardBody({required this.child, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colors.surface.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

/// A static accent badge (replaces the old pulsing ornament for a calmer look).
class _StaticOrnament extends StatelessWidget {
  final Color accent;

  const _StaticOrnament({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            accent,
            Color.lerp(accent, Colors.black, 0.25)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 16,
        color: AppColors.creamWhite,
      ),
    );
  }
}

class _WeekChip extends StatelessWidget {
  final String label;

  const _WeekChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primaryGreen.withValues(alpha: 0.28)
            : AppColors.primaryGreen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryGreenLight.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: colors.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ShareButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: AppLocalizations.of(context)!.shareAyah,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? colors.onSurface.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.15)),
          ),
          child: Icon(
            Icons.ios_share_rounded,
            size: 17,
            color: colors.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
