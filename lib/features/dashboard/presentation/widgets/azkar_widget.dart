import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/azkar_time_logic.dart';
import '../../../../core/utils/quran_render_config.dart';
import '../../../../core/utils/quran_text_normalizer.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../data/database/settings_service.dart';
import '../../../../data/models/prayer_time_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../mushaf/presentation/mushaf_navigation.dart';
import 'azkar_controller.dart';
import 'azkar_share_sheet.dart';

/// A dashboard card that switches its content based on UTC time and local
/// prayer times:
///   • Friday [Jumu'ah + 15 min, Maghrib) → "Surat Al-Kahf" button
///   • 05:00–12:00 UTC                          → morning adhkar
///   • 20:00–01:00 UTC                          → evening adhkar
///   • otherwise                                → seeded general azkar/duaa
///
/// When [embedded] is true the outer card chrome is skipped so the content can
/// be placed inside another card (the share button and period pill stay).
class AzkarWidget extends StatefulWidget {
  final List<PrayerTimeModel> prayerTimes;
  final bool embedded;

  const AzkarWidget({
    super.key,
    this.prayerTimes = const [],
    this.embedded = false,
  });

  @override
  State<AzkarWidget> createState() => _AzkarWidgetState();
}

class _AzkarWidgetState extends State<AzkarWidget> {
  late final AzkarController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AzkarController(prayerTimes: widget.prayerTimes);
  }

  @override
  void didUpdateWidget(covariant AzkarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.prayerTimes, widget.prayerTimes)) {
      _controller.prayerTimes = widget.prayerTimes;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _AzkarCardBody(
          key: ValueKey(_controller.type),
          controller: _controller,
        ),
      );
    }

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final type = _controller.type;
        return GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _AzkarCardBody(
                key: ValueKey(type),
                controller: _controller,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AzkarCardBody extends StatelessWidget {
  const _AzkarCardBody({super.key, required this.controller});

  final AzkarController controller;

  @override
  Widget build(BuildContext context) {
    final type = controller.type;
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final (icon, title, accent) = switch (type) {
      AzkarWidgetType.morning => (
          Icons.wb_sunny_rounded,
          l10n.morningAzkar,
          const Color(0xFFF59E0B),
        ),
      AzkarWidgetType.evening => (
          Icons.nightlight_round,
          l10n.eveningAzkar,
          const Color(0xFF818CF8),
        ),
      AzkarWidgetType.kahf => (
          Icons.menu_book_rounded,
          l10n.suratAlKahf,
          AppColors.primaryGreenLight,
        ),
      AzkarWidgetType.general => (
          Icons.spa_rounded,
          l10n.generalAzkar,
          const Color(0xFF14B8A6),
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.arabicTitle.copyWith(
                  fontSize: 16,
                  color: onSurface,
                ),
              ),
            ),
            _PeriodPill(type: type, accent: accent),
            const SizedBox(width: 6),
            // Innermost gesture wins the arena, so the share button does not
            // trigger any surrounding navigation.
            _AzkarShareButton(
              accent: accent,
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AzkarShareSheet(
                    item: controller.item,
                    type: controller.type,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (type == AzkarWidgetType.kahf)
          _KahfButton(accent: accent)
        else
          _AzkarText(item: controller.item, accent: accent, onSurface: onSurface),
      ],
    );
  }
}

/// Small pill showing the rule's UTC window (e.g. "05:00–12:00 UTC").
class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.type, required this.accent});

  final AzkarWidgetType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (type) {
      AzkarWidgetType.morning => '05:00–12:00',
      AzkarWidgetType.evening => '20:00–01:00',
      AzkarWidgetType.kahf => l10n.friday,
      AzkarWidgetType.general => l10n.always,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}

/// Full-width gradient button that opens Surat Al-Kahf (18) in the mushaf.
class _KahfButton extends StatelessWidget {
  const _KahfButton({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, Color.lerp(accent, Colors.black, 0.28)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => MushafNavigation.open(
            context,
            MushafNavigation.forSurah(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.menu_book_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.readSuratAlKahf,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The seeded azkar text (Amiri Quran font) with its reference chip.
class _AzkarText extends StatelessWidget {
  const _AzkarText({
    required this.item,
    required this.accent,
    required this.onSurface,
  });

  final AzkarItem item;
  final Color accent;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    // Same sanitization the mushaf uses, so no orphaned marks (dotted circles).
    final text = QuranTextNormalizer.preProcessForDisplay(item.text);
    final refLang = SettingsService.translationLanguage;
    final ref = item.translatedReference(refLang) ?? item.reference;
    final trText = item.translatedText(refLang);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: QuranRenderConfig.quranStyle(
              fontSize: 17,
              color: onSurface,
            ).copyWith(height: 1.9),
          ),
        ),
        if (trText != null) ...[
          const SizedBox(height: 6),
          Directionality(
            textDirection: refLang == 'en'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: Text(
              trText,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                color: onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ),
        ],
        if (ref != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Directionality(
                textDirection: refLang == 'en'
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    ref,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Round share button tinted with the azkar category accent, mirroring the
/// ayah card's share button.
class _AzkarShareButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onPressed;

  const _AzkarShareButton({required this.accent, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: AppLocalizations.of(context)!.shareAzkar,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? accent.withValues(alpha: 0.14)
                : accent.withValues(alpha: 0.08),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Icon(
            Icons.ios_share_rounded,
            size: 16,
            color: accent,
          ),
        ),
      ),
    );
  }
}
