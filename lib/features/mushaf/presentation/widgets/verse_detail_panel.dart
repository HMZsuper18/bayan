import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../../core/utils/quran_render_config.dart';
import '../../../../core/utils/quran_text_normalizer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../data/models/verse_model.dart';
import '../../../../data/models/reciter_model.dart';
import '../../../../services/default_reciter_service.dart';
import '../../../../services/reciter_store_service.dart';

class VerseDetailPanel extends StatefulWidget {
  final VerseModel verse;
  final String? tafseer;
  final String? translation;
  final String? qiraat;
  final Future<void> Function()? onPlaySingleVerse;
  final Future<void> Function()? onPlayToEndOfSurah;
  final int? surahVersesCount;
  final ScrollController? scrollController;

  const VerseDetailPanel({
    super.key,
    required this.verse,
    required this.tafseer,
    this.translation,
    required this.qiraat,
    this.onPlaySingleVerse,
    this.onPlayToEndOfSurah,
    this.surahVersesCount,
    this.scrollController,
  });

  @override
  State<VerseDetailPanel> createState() => _VerseDetailPanelState();
}

class _VerseDetailPanelState extends State<VerseDetailPanel> {
  List<ReciterModel> _downloadedReciters = [];
  int _currentReciterIndex = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  bool get _isLastVerse =>
      widget.surahVersesCount != null &&
      widget.verse.verseNumber == widget.surahVersesCount;

  bool get _hasPlayback =>
      widget.onPlaySingleVerse != null || widget.onPlayToEndOfSurah != null;

  @override
  void initState() {
    super.initState();
    _loadDownloadedReciters();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDownloadedReciters() async {
    final reciters =
        await ReciterStoreService.instance.getDownloadedReciters();
    if (!mounted) return;
    setState(() {
      _downloadedReciters = reciters;
    });
    _centerOnDefaultReciter();
  }

  void _centerOnDefaultReciter() {
    if (_downloadedReciters.isEmpty) return;
    final defaultId = DefaultReciterService.getDefaultReciterId();
    if (defaultId != null) {
      final idx = _downloadedReciters.indexWhere((r) => r.id == defaultId);
      if (idx >= 0) {
        _currentReciterIndex = idx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _carouselController.animateToPage(idx,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
          }
        });
      }
    } else {
      // No default reciter set yet — make the first downloaded reciter the
      // default so the play buttons work immediately.
      final first = _downloadedReciters.first;
      _currentReciterIndex = 0;
      DefaultReciterService.setDefaultReciterId(first.id);
    }
  }

  void _onReciterChanged(int index, CarouselPageChangedReason reason) {
    setState(() => _currentReciterIndex = index);
    final reciter = _downloadedReciters[index];
    DefaultReciterService.setDefaultReciterId(reciter.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return ListView(
      controller: widget.scrollController,
      // Extra bottom padding so the last line stays visible above the
      // mini player, which is always pinned on top of the sheet.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Play buttons & reciter carousel
        if (_hasPlayback || _downloadedReciters.isNotEmpty)
          _buildButtonsAndCarouselRow(context, l10n),
        if (_hasPlayback || _downloadedReciters.isNotEmpty)
          const SizedBox(height: 14),
        // Qiraat section
        if (widget.qiraat != null && widget.qiraat!.isNotEmpty) ...[
          Divider(color: colors.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            l10n.qiraat,
            style: AppTextStyles.arabicTitle.copyWith(
              fontSize: 14,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              QuranTextNormalizer.preProcessForDisplay(widget.qiraat!),
              style: TextStyle(
                fontFamily: QuranRenderConfig.fontFamily,
                fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
                fontSize: 14,
                height: 1.8,
                color: colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Translation section
        if (widget.translation != null && widget.translation!.isNotEmpty) ...[
          Divider(color: colors.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            l10n.translation,
            style: AppTextStyles.arabicTitle.copyWith(
              fontSize: 14,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              widget.translation!,
              style: TextStyle(
                fontSize: 13,
                height: 1.8,
                color: colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Tafseer section
        if (widget.tafseer != null && widget.tafseer!.isNotEmpty) ...[
          Divider(color: colors.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            l10n.tafseer,
            style: AppTextStyles.arabicTitle.copyWith(
              fontSize: 14,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              widget.tafseer!,
              style: TextStyle(
                fontSize: 13,
                height: 1.8,
                color: colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildButtonsAndCarouselRow(
      BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasPlayback) ...[
          _buildPlayButtonsColumn(context, l10n),
          const SizedBox(width: 20),
        ],
        if (_downloadedReciters.isNotEmpty)
          Expanded(
            child: _buildReciterCarousel(context, l10n),
          ),
      ],
    );
  }

  Widget _buildPlayButtonsColumn(BuildContext context, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onPlaySingleVerse != null)
          _buildGlassButton(
            context: context,
            label: l10n.playSingleVerse,
            icon: Icons.play_arrow_rounded,
            onPressed: widget.onPlaySingleVerse!,
          ),
        if (widget.onPlaySingleVerse != null &&
            widget.onPlayToEndOfSurah != null &&
            !_isLastVerse)
          const SizedBox(height: 6),
        if (widget.onPlayToEndOfSurah != null && !_isLastVerse)
          _buildGlassButton(
            context: context,
            label: l10n.playFullSurah,
            icon: Icons.queue_music_rounded,
            onPressed: widget.onPlayToEndOfSurah!,
          ),
      ],
    );
  }

  Widget _buildGlassButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: GlassContainer(
        borderRadius: 12,
        blur: 6,
        opacity: 0.1,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReciterCarousel(BuildContext context, AppLocalizations l10n) {
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
            if (_downloadedReciters.isNotEmpty)
              Text(
                '${_currentReciterIndex + 1}/${_downloadedReciters.length}',
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
          itemCount: _downloadedReciters.length,
          options: CarouselOptions(
            height: 90,
            viewportFraction: 0.35,
            enableInfiniteScroll: false,
            enlargeCenterPage: true,
            scrollPhysics: const BouncingScrollPhysics(),
            onPageChanged: _onReciterChanged,
          ),
          itemBuilder: (context, index, _) {
            final reciter = _downloadedReciters[index];
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
            final idx = _downloadedReciters.indexOf(reciter);
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
}
