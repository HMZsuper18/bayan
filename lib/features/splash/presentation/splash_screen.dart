import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_container.dart';

class SplashScreen extends StatelessWidget {
  final bool isDark;

  const SplashScreen({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      colors: isDark
          ? [const Color(0xFF0A1F1A), const Color(0xFF061210)]
          : [AppColors.creamWhite, AppColors.surfaceGreen],
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGreen,
                          AppColors.primaryGreenLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SvgPicture.asset(
                        'assets/images/logo.svg',
                        colorFilter: const ColorFilter.mode(
                          AppColors.creamWhite,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GlassContainer(
                    borderRadius: 20,
                    blur: 10,
                    opacity: 0.15,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.splashVerse,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.arabicSlogan,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.splashSurahRef,
                          style: AppTextStyles.englishBody.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.loading,
                    style: AppTextStyles.englishBody.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}