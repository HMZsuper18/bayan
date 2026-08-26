import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/azkar_time_logic.dart';
import '../../../../core/utils/quran_render_config.dart';
import '../../../../core/utils/quran_text_normalizer.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../data/database/settings_service.dart';
import '../../../../l10n/app_localizations.dart';

/// Bottom sheet that renders the shareable azkar poster image, lets the user
/// preview it, and shares it via the system share sheet.
class AzkarShareSheet extends StatefulWidget {
  final AzkarItem item;
  final AzkarWidgetType type;

  const AzkarShareSheet({
    super.key,
    required this.item,
    required this.type,
  });

  @override
  State<AzkarShareSheet> createState() => _AzkarShareSheetState();
}

class _AzkarShareSheetState extends State<AzkarShareSheet> {
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
              name: 'azkar.png',
            ),
          ],
          text: l10n.azkarShareAd,
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
            _AzkarDragHandle(),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                AzkarPoster.title(l10n, widget.type),
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
                    // The poster's height adapts to the azkar length, so the
                    // captured image always contains the full text. The scroll
                    // view here is only for previewing a tall poster on screen.
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width =
                            constraints.maxWidth < AzkarPoster.posterWidth
                            ? constraints.maxWidth
                            : AzkarPoster.posterWidth;
                        return AzkarPoster(
                          item: widget.item,
                          type: widget.type,
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
                    _sharing ? l10n.processing : l10n.shareAzkar,
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

class _AzkarDragHandle extends StatelessWidget {
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

/// The shareable azkar poster: fixed logical width (rendered at 3x for a crisp
/// image) with a height that grows to fit the text, so nothing is ever cut.
/// Its gradient is tinted by the azkar category accent, matching the card.
class AzkarPoster extends StatelessWidget {
  final AzkarItem item;
  final AzkarWidgetType type;

  /// Optional override for narrow screens; defaults to [posterWidth].
  final double width;

  const AzkarPoster({
    super.key,
    required this.item,
    required this.type,
    this.width = posterWidth,
  });

  static const double posterWidth = 360;

  static Color accent(AzkarWidgetType type) {
    switch (type) {
      case AzkarWidgetType.morning:
        return const Color(0xFFF59E0B);
      case AzkarWidgetType.evening:
        return const Color(0xFF818CF8);
      case AzkarWidgetType.kahf:
        return AppColors.primaryGreenLight;
      case AzkarWidgetType.general:
        return const Color(0xFF14B8A6);
    }
  }

  static String title(AppLocalizations l10n, AzkarWidgetType type) {
    switch (type) {
      case AzkarWidgetType.morning:
        return l10n.morningAzkar;
      case AzkarWidgetType.evening:
        return l10n.eveningAzkar;
      case AzkarWidgetType.kahf:
        return l10n.suratAlKahf;
      case AzkarWidgetType.general:
        return l10n.generalAzkar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = AzkarPoster.accent(type);
    final deepAccent = Color.lerp(accent, Colors.black, 0.4)!;
    final brightAccent = Color.lerp(accent, Colors.white, 0.15)!;
    final text = QuranTextNormalizer.preProcessForDisplay(item.text);
    final refLang = SettingsService.translationLanguage;
    final ref = item.translatedReference(refLang) ?? item.reference;

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deepAccent, accent, brightAccent],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x66FFFFFF), width: 1.4),
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
                  color: Color(0xFFFFF3E0),
                ),
                const SizedBox(width: 8),
                Text(
                  'Bayan',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: const Color(0xFFFFF3E0),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: Color(0xFFFFF3E0),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title(l10n, type),
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Colors.white.withValues(alpha: 0.92),
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
                    Colors.white.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            // Azkar text — wraps naturally, growing the poster so nothing is cut.
            Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: QuranRenderConfig.fontFamily,
                    fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
                    fontSize: 24,
                    height: 2.0,
                    color: const Color(0xFFFDFBF7),
                    fontFeatures: QuranRenderConfig.openTypeFeatures,
                  ),
                ),
              ),
            ),
            if (item.translatedText(refLang) case final trText?) ...[
              const SizedBox(height: 6),
              Directionality(
                textDirection: refLang == 'en'
                    ? TextDirection.ltr
                    : TextDirection.rtl,
                child: Text(
                  trText,
                  textAlign: TextAlign.center,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ],
            if (ref != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Directionality(
                  textDirection: refLang == 'en'
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  child: Text(
                    ref,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
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
                l10n.azkarShareAd,
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
