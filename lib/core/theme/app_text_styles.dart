import 'package:flutter/material.dart';
import 'package:bayan/core/utils/quran_render_config.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String _tajawal = 'Tajawal';

  static final TextStyle arabicDisplay = TextStyle(
    fontFamily: QuranRenderConfig.fontFamily,
    fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
    fontSize: 28,
    color: AppColors.textPrimary,
    height: 2.2,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: QuranRenderConfig.openTypeFeatures,
  );

  static final TextStyle arabicVerse = TextStyle(
    fontFamily: QuranRenderConfig.fontFamily,
    fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
    fontSize: 22,
    color: AppColors.textPrimary,
    height: 2.2,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: QuranRenderConfig.openTypeFeatures,
  );

  static const TextStyle arabicTitle = TextStyle(
    fontFamily: _tajawal,
    fontSize: 20,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle englishHeading = TextStyle(
    fontFamily: _tajawal,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle englishSubtitle = TextStyle(
    fontFamily: _tajawal,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  static const TextStyle englishBody = TextStyle(
    fontFamily: _tajawal,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: _tajawal,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle arabicSlogan = TextStyle(
    fontFamily: _tajawal,
    fontSize: 18,
    color: AppColors.primaryGreen,
    height: 1.6,
  );

  static const TextStyle tafseerText = TextStyle(
    fontFamily: _tajawal,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );
}