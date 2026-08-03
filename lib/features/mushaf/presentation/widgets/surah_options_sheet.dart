import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../data/models/reciter_model.dart';
import '../../../../data/models/surah_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/default_reciter_service.dart';

class SurahOptionsSheet extends StatefulWidget {
  final SurahModel surah;
  final VoidCallback? onPlayFullSurah;
  final List<ReciterModel>? reciters;
  final ValueChanged<ReciterModel>? onReciterChanged;
  final int initialReciterIndex;

  const SurahOptionsSheet({
    super.key,
    required this.surah,
    this.onPlayFullSurah,
    this.reciters,
    this.onReciterChanged,
    this.initialReciterIndex = 0,
  });

  @override
  State<SurahOptionsSheet> createState() => _SurahOptionsSheetState();
}

class _SurahOptionsSheetState extends State<SurahOptionsSheet> {
  int _currentReciterIndex = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  void initState() {
    super.initState();
    _currentReciterIndex = _resolveInitialIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentReciterIndex > 0) {
        _carouselController.animateToPage(
          _currentReciterIndex,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  int _resolveInitialIndex() {
    if (widget.reciters == null || widget.reciters!.isEmpty) return 0;
    final defaultId = DefaultReciterService.getDefaultReciterId();
    if (defaultId == null) {
      // No default reciter set yet — make the first downloaded reciter the
      // default so the play button works immediately.
      final first = widget.reciters!.first;
      DefaultReciterService.setDefaultReciterId(first.id);
      return widget.initialReciterIndex;
    }
    final idx = widget.reciters!.indexWhere((r) => r.id == defaultId);
    return idx >= 0 ? idx : widget.initialReciterIndex;
  }

  void _onReciterChanged(int index, CarouselPageChangedReason reason) {
    setState(() => _currentReciterIndex = index);
    final reciters = widget.reciters;
    if (reciters != null && index < reciters.length) {
      widget.onReciterChanged?.call(reciters[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reciters = widget.reciters ?? [];

    final bgColor = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.3);

    final surface = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Surah name & info
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    widget.surah.name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.arabicDisplay.copyWith(
                      fontSize: 26,
                      color: colors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.surah.englishName,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                // Row: Play button + Reciter carousel
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _compactGlassButton(
                      context: context,
                      icon: Icons.play_arrow_rounded,
                      label: l10n.playFullSurahFromStart,
                      color: AppColors.primaryGreen,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onPlayFullSurah?.call();
                      },
                    ),
                    const SizedBox(width: 16),
                    if (reciters.isNotEmpty)
                      Expanded(
                        child: _buildReciterCarousel(context, l10n, reciters),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return surface;
  }

  Widget _buildReciterCarousel(
    BuildContext context,
    AppLocalizations l10n,
    List<ReciterModel> reciters,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.selectReciter,
              style: AppTextStyles.arabicTitle.copyWith(
                fontSize: 12,
                color: AppColors.primaryGreen,
              ),
            ),
            Text(
              '${_currentReciterIndex + 1}/${reciters.length}',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CarouselSlider.builder(
          carouselController: _carouselController,
          itemCount: reciters.length,
          options: CarouselOptions(
            height: 90,
            viewportFraction: 0.35,
            enableInfiniteScroll: false,
            enlargeCenterPage: true,
            scrollPhysics: const BouncingScrollPhysics(),
            onPageChanged: _onReciterChanged,
          ),
          itemBuilder: (context, index, _) {
            final reciter = reciters[index];
            final isCentered = index == _currentReciterIndex;
            return _buildReciterItem(
              context: context,
              reciter: reciter,
              isCentered: isCentered,
              l10n: l10n,
            );
          },
        ),
      ],
    );
  }

  Widget _buildReciterItem({
    required BuildContext context,
    required ReciterModel reciter,
    required bool isCentered,
    required AppLocalizations l10n,
  }) {
    final colors = Theme.of(context).colorScheme;
    final displayName = _reciterDisplayName(l10n, reciter);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      transform: Matrix4.diagonal3Values(
          isCentered ? 1.0 : 0.82, isCentered ? 1.0 : 0.82, 1.0),
      transformAlignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          if (!isCentered) {
            final idx = widget.reciters?.indexOf(reciter) ?? 0;
            _carouselController.animateToPage(idx,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }
        },
        child: GlassContainer(
          borderRadius: 14,
          blur: isCentered ? 8 : 4,
          opacity: isCentered ? 0.15 : 0.08,
          border: Border.all(
            color: isCentered
                ? AppColors.primaryGreen.withValues(alpha: 0.6)
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.3)),
            width: isCentered ? 1.5 : 0.8,
          ),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: reciter.imageAsset.isNotEmpty
                      ? DecorationImage(
                          image: AssetImage(reciter.imageAsset),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: AppColors.primaryGreen.withValues(alpha: 0.2),
                ),
                child: reciter.imageAsset.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        color: AppColors.primaryGreen,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        isCentered ? FontWeight.w600 : FontWeight.w400,
                    color: isCentered
                        ? AppColors.primaryGreen
                        : colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _reciterDisplayName(AppLocalizations l10n, ReciterModel reciter) {
    switch (reciter.id) {
      case 'mishary':
        return l10n.reciterName_mishary;
      case 'sudais':
        return l10n.reciterName_sudais;
      case 'shuraim':
        return l10n.reciterName_shuraim;
      case 'muaiqly':
        return l10n.reciterName_muaiqly;
      case 'dosari':
        return l10n.reciterName_dosari;
      case 'ajmi':
        return l10n.reciterName_ajmi;
      case 'ghamdi':
        return l10n.reciterName_ghamdi;
      case 'huthaify':
        return l10n.reciterName_huthaify;
      case 'abdulbasit':
        return l10n.reciterName_abdulbasit;
      case 'husary':
        return l10n.reciterName_husary;
      case 'minshawi':
        return l10n.reciterName_minshawi;
      case 'banna':
        return l10n.reciterName_banna;
      default:
        return reciter.arabicName.isNotEmpty ? reciter.arabicName : reciter.name;
    }
  }

  Widget _compactGlassButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 12,
        blur: 6,
        opacity: 0.1,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the surah options bottom sheet.
Future<void> showSurahOptionsSheet(
  BuildContext context, {
  required SurahModel surah,
  required VoidCallback? onPlayFullSurah,
  List<ReciterModel>? reciters,
  ValueChanged<ReciterModel>? onReciterChanged,
  int initialReciterIndex = 0,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => SurahOptionsSheet(
      surah: surah,
      onPlayFullSurah: onPlayFullSurah,
      reciters: reciters,
      onReciterChanged: onReciterChanged,
      initialReciterIndex: initialReciterIndex,
    ),
  );
}
