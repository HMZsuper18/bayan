import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_container.dart';

class SurahHeaderWidget extends StatelessWidget {
  final dynamic surah;
  final double fontSize;
  final VoidCallback? onTap;

  const SurahHeaderWidget({
    super.key,
    required this.surah,
    required this.fontSize,
    this.onTap,
  });

  static double _circleSize(int n) {
    final digits = n.toString().length;
    if (digits > 2) return 72;
    if (digits > 1) return 64;
    return 56;
  }

  static String _arabicIndic(int n) {
    const digits = [
      '\u0660',
      '\u0661',
      '\u0662',
      '\u0663',
      '\u0664',
      '\u0665',
      '\u0666',
      '\u0667',
      '\u0668',
      '\u0669',
    ];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final revelationType = surah.revelationType == 'Makkah' ? l10n.makkah : l10n.madinah;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: GlassContainer(
        width: double.infinity,
        borderRadius: 20,
        blur: 12,
        opacity: 0.12,
        padding: EdgeInsets.zero,
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.6), width: 1.2),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: GlassContainer(
                        borderRadius: 20,
                        opacity: 0.08,
                        blur: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                        child: Text(
                          revelationType,
                          style: AppTextStyles.arabicDisplay.copyWith(
                            fontSize: fontSize - 4,
                            color: colors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      surah.name,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.arabicDisplay.copyWith(
                        fontSize: fontSize + 10,
                        color: colors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Container(
                      width: _circleSize(surah.versesCount),
                      height: _circleSize(surah.versesCount),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryGreen,
                          width: 1.5,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            _arabicIndic(surah.versesCount),
                            style: TextStyle(
                              fontSize: fontSize + 4,
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
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
