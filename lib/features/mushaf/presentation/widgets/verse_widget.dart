import 'package:flutter/material.dart';
import 'package:bayan/core/utils/quran_render_config.dart';
import 'package:bayan/core/utils/quran_text_normalizer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/verse_model.dart';

class VerseWidget extends StatelessWidget {
  final VerseModel verse;
  final bool isSelected;
  final double fontSize;
  final VoidCallback onTap;

  const VerseWidget({
    super.key,
    required this.verse,
    required this.isSelected,
    required this.fontSize,
    required this.onTap,
  });

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
    final colors = Theme.of(context).colorScheme;
    final rosetteSize = fontSize * 1.5;
    final numberSize = fontSize * 0.55;
    final style = AppTextStyles.arabicVerse.copyWith(
      fontSize: fontSize,
      color: colors.onSurface,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.5))
              : null,
        ),
        child: QuranRenderConfig.rtl(
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  QuranTextNormalizer.preProcessForDisplay(verse.textUthmani),
                  textAlign: TextAlign.right,
                  style: style,
                ),
              ),
              SizedBox(
                width: rosetteSize * 1.3,
                height: rosetteSize * 1.3,
                child: Padding(
                  padding: EdgeInsets.only(bottom: rosetteSize * 0.15),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment(0, 1),
                        child: Text(
                          _arabicIndic(verse.verseNumber),
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: numberSize,
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
