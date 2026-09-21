import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

class DesktopShell extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const DesktopShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.primaryGreenOf(context);
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth <= 900) {
      return widget.child;
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.primaryGreenOf(context).withValues(alpha: 0.06),
              border: Border(
                right: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.primaryGreenOf(context).withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mosque_rounded,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 24),
                _NavButton(
                  icon: Icons.home_rounded,
                  label: l10n.home,
                  isActive: widget.currentIndex == 0,
                  onTap: () => widget.onIndexChanged(0),
                  accent: accent,
                ),
                _NavButton(
                  icon: Icons.menu_book_rounded,
                  label: l10n.quranIndex,
                  isActive: widget.currentIndex == 1,
                  onTap: () => widget.onIndexChanged(1),
                  accent: accent,
                ),
                _NavButton(
                  icon: Icons.record_voice_over_rounded,
                  label: l10n.reciters,
                  isActive: widget.currentIndex == 2,
                  onTap: () => widget.onIndexChanged(2),
                  accent: accent,
                ),
                _NavButton(
                  icon: Icons.explore_rounded,
                  label: l10n.qiblah,
                  isActive: widget.currentIndex == 3,
                  onTap: () => widget.onIndexChanged(3),
                  accent: accent,
                ),
                const Spacer(),
                _NavButton(
                  icon: Icons.settings_rounded,
                  label: l10n.settings,
                  isActive: widget.currentIndex == 4,
                  onTap: () => widget.onIndexChanged(4),
                  accent: accent,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color accent;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? accent.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isActive
                        ? accent
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.primaryGreenOf(context).withValues(alpha: 0.5)),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? accent
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : AppColors.primaryGreenOf(context).withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
