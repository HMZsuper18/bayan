import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_container.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _developer = 'Hamzah Ahmed';
  static const String _email = 'hamzah.arkoub@gmail.com';
  static const String _portfolioLabel = 'hmzsuper18.github.io';
  static const String _repositoryLabel = 'github.com/HMZsuper18/bayan';

  Future<void> _launchUrl(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.aboutOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassBackground(
      child: Scaffold(
        appBar: AppBar(
          leading: GlassContainer(
            borderRadius: 20,
            blur: 6,
            opacity: 0.08,
            padding: EdgeInsets.zero,
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          title: Text(l10n.aboutApp),
        ),
        body: Center(
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
                        l10n.splashVerse,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.arabicSlogan,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.splashSurahRef,
                        style: AppTextStyles.englishBody.copyWith(
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GlassContainer(
                  borderRadius: 20,
                  blur: 10,
                  opacity: 0.15,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _AboutRow(
                        icon: Icons.person_rounded,
                        color: AppColors.primaryGreen,
                        label: l10n.aboutDeveloper,
                        value: _developer,
                      ),
                      _AboutRow(
                        icon: Icons.mail_rounded,
                        color: AppColors.primaryGreenLight,
                        label: l10n.aboutEmail,
                        value: _email,
                        onTap: () => _launchUrl(context, 'mailto:$_email'),
                      ),
                      _AboutRow(
                        icon: Icons.public_rounded,
                        color: AppColors.primaryGreen,
                        label: l10n.aboutPortfolio,
                        value: _portfolioLabel,
                        onTap: () => _launchUrl(
                          context,
                          'https://$_portfolioLabel/',
                        ),
                      ),
                      _AboutRow(
                        icon: Icons.code_rounded,
                        color: AppColors.primaryGreenLight,
                        label: l10n.aboutRepository,
                        value: _repositoryLabel,
                        onTap: () => _launchUrl(
                          context,
                          'https://$_repositoryLabel',
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: onSurface.withValues(alpha: 0.6),
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTextStyles.englishBody.copyWith(
                      fontWeight: FontWeight.w600,
                      color: onTap == null
                          ? onSurface
                          : AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.open_in_new_rounded,
                size: 15,
                color: onSurface.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: content,
    );
  }
}
