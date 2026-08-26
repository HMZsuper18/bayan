import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../mushaf/presentation/mushaf_scanner_screen.dart';
import '../../../quran_index/presentation/quran_index_screen.dart';

class SearchBarWidget extends StatelessWidget {
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearch;
  final VoidCallback? onClear;

  const SearchBarWidget({
    super.key,
    this.onSearchChanged,
    this.onSearch,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassContainer(
        borderRadius: 16,
        blur: 8,
        opacity: isDark ? 0.2 : 0.1,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 22,
                constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                icon: const Icon(Icons.book, color: AppColors.primaryGreen),
                tooltip: AppLocalizations.of(context)!.indexTitle,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QuranIndexScreen()),
                  );
                },
              ),
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 22,
                constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                icon: Badge(
                  label: Text(AppLocalizations.of(context)!.betaLabel, style: const TextStyle(fontSize: 9, color: Colors.white)),
                  smallSize: 18,
                  alignment: Alignment.bottomRight,
                  backgroundColor: AppColors.primaryGreen,
                  textStyle: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                  child: const Icon(Icons.document_scanner, color: AppColors.primaryGreen),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MushafScannerScreen()),
                  );
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    onSearchChanged?.call(value);
                    onSearch?.call(value);
                  },
                  textDirection: TextDirection.rtl,
                  style: AppTextStyles.englishBody.copyWith(
                    color: colors.onSurface,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchHint,
                    hintTextDirection: TextDirection.rtl,
                    hintStyle: AppTextStyles.englishBody.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(
                    Icons.search,
                    size: 22,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
