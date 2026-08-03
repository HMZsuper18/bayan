import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bayan/core/utils/quran_render_config.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/mini_player.dart';
import '../../../data/database/settings_service.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/models/reciter_model.dart';
import '../../../data/models/surah_model.dart';
import '../../../data/models/verse_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_playback_service.dart';
import '../../../services/default_reciter_service.dart';
import '../../../services/reciter_store_service.dart';
import 'widgets/adaptive_quran_renderer.dart';
import 'widgets/surah_header_widget.dart';
import 'widgets/verse_detail_panel.dart';
import 'widgets/surah_options_sheet.dart';

class MushafPageViewer extends StatefulWidget {
  final int initialPage;
  final int? initialVerseId;

  const MushafPageViewer({
    super.key,
    this.initialPage = 1,
    this.initialVerseId,
  });

  @override
  State<MushafPageViewer> createState() => _MushafPageViewerState();
}

class _MushafPageViewerState extends State<MushafPageViewer> {
  late PageController _pageController;
  final _repository = QuranRepository();
  final _audioService = AudioPlaybackService.instance;
  final _reciterStore = ReciterStoreService.instance;
  VerseModel? _selectedVerse;
  String? _tafseer;
  String? _translation;
  String? _qiraat;
  List<ReciterModel> _downloadedReciters = [];
  Timer? _verseSwitchTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage - 1);
    _loadReciters();
    if (widget.initialVerseId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _highlightVerse(widget.initialVerseId!),
      );
    }
  }

  Future<void> _loadReciters() async {
    final reciters = await _reciterStore.getDownloadedReciters();
    if (mounted) setState(() => _downloadedReciters = reciters);
  }

  @override
  void dispose() {
    _verseSwitchTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
          title: Text(
            AppLocalizations.of(context)!.mushaf,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: 604,
              onPageChanged: (_) {
                setState(() {
                  _selectedVerse = null;
                  _tafseer = null;
                  _translation = null;
                  _qiraat = null;
                });
              },
              itemBuilder: (context, index) {
                final pageNum = index + 1;
                return RepaintBoundary(
                  child: _LazyPageContent(
                    pageNum: pageNum,
                    repository: _repository,
                    selectedVerse: _selectedVerse,
                    onVerseTap: _onVerseTap,
                    onSurahTap: _onSurahHeaderTap,
                  ),
                );
              },
            ),
            _TafseerSheetV2(
              selectedVerse: _selectedVerse,
              tafseer: _tafseer,
              translation: _translation,
              qiraat: _qiraat,
              colors: Theme.of(context).colorScheme,
              onDismiss: () {
                setState(() {
                  _selectedVerse = null;
                  _tafseer = null;
                  _translation = null;
                  _qiraat = null;
                });
              },
              onPlaySingleVerse: _playSelectedVerse,
              onPlayToEndOfSurah: _playFromVerseToEndOfSurah,
            ),
            // Mini player pinned to the bottom, on top of everything (sheets,
            // pages) so playback controls stay reachable at all times.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
          ],
        ),
      ),
    );
  }

  void _highlightVerse(int verseId) {
    final verse = _repository.getVerse(verseId);
    if (verse != null) {
      _onVerseTap(verse);
    }
  }

  void _onVerseTap(VerseModel verse) {
    // The basmalah is a header, not a verse — never select it.
    if (verse.surahId == 1 && verse.verseNumber == 1) return;
    _verseSwitchTimer?.cancel();
    if (_selectedVerse?.id == verse.id) {
      setState(() {
        _selectedVerse = null;
        _tafseer = null;
        _translation = null;
        _qiraat = null;
      });
      return;
    }
    HapticFeedback.selectionClick();
    if (_selectedVerse != null) {
      // Close the old sheet first, then open the new one after animation
      setState(() {
        _selectedVerse = null;
        _tafseer = null;
        _translation = null;
        _qiraat = null;
      });
      _verseSwitchTimer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        final key = '${verse.surahId}:${verse.verseNumber}';
        setState(() {
          _selectedVerse = verse;
          _tafseer = _repository.getTafseer(
            key,
            language: SettingsService.tafseerLanguage,
          );
          _translation = _repository.getTranslation(
            key,
            language: SettingsService.translationLanguage,
          );
          _qiraat = _repository.getQiraat(key);
        });
      });
    } else {
      final key = '${verse.surahId}:${verse.verseNumber}';
      setState(() {
        _selectedVerse = verse;
        _tafseer = _repository.getTafseer(
          key,
          language: SettingsService.tafseerLanguage,
        );
        _translation = _repository.getTranslation(
          key,
          language: SettingsService.translationLanguage,
        );
        _qiraat = _repository.getQiraat(key);
      });
    }
  }

  void _onSurahHeaderTap(SurahModel surah) {
    HapticFeedback.mediumImpact();
    showSurahOptionsSheet(
      context,
      surah: surah,
      onPlayFullSurah: () => _playFullSurah(surah),
      reciters: _downloadedReciters,
      onReciterChanged: (reciter) {
        DefaultReciterService.setDefaultReciterId(reciter.id);
      },
    );
  }

  Future<void> _playFullSurah(SurahModel surah) async {
    final (reciter, isValid, errorMessage) =
        DefaultReciterService.validateDefaultReciter();
    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage ?? AppLocalizations.of(context)!.unknownError)),
        );
      }
      return;
    }
    await _audioService.playFromVerseToEnd(
      surahId: surah.id,
      verseNumber: 1,
      reciter: reciter!,
    );
  }

  Future<void> _playSelectedVerse() async {
    final verse = _selectedVerse;
    if (verse == null) return;
    final (reciter, isValid, errorMessage) =
        DefaultReciterService.validateDefaultReciter();
    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage ?? AppLocalizations.of(context)!.unknownError)),
        );
      }
      return;
    }
    await _audioService.playSingleVerse(
      surahId: verse.surahId,
      verseNumber: verse.verseNumber,
      reciter: reciter!,
    );
  }

  Future<void> _playFromVerseToEndOfSurah() async {
    final verse = _selectedVerse;
    if (verse == null) return;
    final (reciter, isValid, errorMessage) =
        DefaultReciterService.validateDefaultReciter();
    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage ?? AppLocalizations.of(context)!.unknownError)),
        );
      }
      return;
    }
    await _audioService.playFromVerseToEnd(
      surahId: verse.surahId,
      verseNumber: verse.verseNumber,
      reciter: reciter!,
    );
  }
}

class _SurahBlock {
  final SurahModel surah;
  final List<VerseModel> verses;
  _SurahBlock({required this.surah, required this.verses});
}

class _PageData {
  final int page;
  final List<_SurahBlock> blocks;
  _PageData({required this.page, required this.blocks});
}

_PageData _loadPageData(QuranRepository repository, int pageNum) {
  final pageVerses = repository.getVersesByPage(pageNum);
  final blocks = <_SurahBlock>[];
  int? currentSurahId;
  List<VerseModel> currentVerses = [];

  for (final v in pageVerses) {
    if (v.surahId != currentSurahId) {
      if (currentVerses.isNotEmpty) {
        final surah = repository.getSurahById(currentSurahId!);
        if (surah != null) {
          blocks.add(
            _SurahBlock(surah: surah, verses: List.from(currentVerses)),
          );
        }
        currentVerses.clear();
      }
      currentSurahId = v.surahId;
    }
    currentVerses.add(v);
  }
  if (currentVerses.isNotEmpty && currentSurahId != null) {
    final surah = repository.getSurahById(currentSurahId);
    if (surah != null) {
      blocks.add(_SurahBlock(surah: surah, verses: currentVerses));
    }
  }
  return _PageData(page: pageNum, blocks: blocks);
}

class _LazyPageContent extends StatefulWidget {
  final int pageNum;
  final QuranRepository repository;
  final VerseModel? selectedVerse;
  final void Function(VerseModel) onVerseTap;
  final void Function(SurahModel) onSurahTap;

  const _LazyPageContent({
    required this.pageNum,
    required this.repository,
    required this.selectedVerse,
    required this.onVerseTap,
    required this.onSurahTap,
  });

  @override
  State<_LazyPageContent> createState() => _LazyPageContentState();
}

class _LazyPageContentState extends State<_LazyPageContent> {
  _PageData? _pageData;

  @override
  void initState() {
    super.initState();
    _pageData = _loadPageData(widget.repository, widget.pageNum);
  }

  @override
  void didUpdateWidget(_LazyPageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNum != widget.pageNum) {
      _pageData = _loadPageData(widget.repository, widget.pageNum);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageData = _pageData!;
    return _PageContent(
      pageNum: widget.pageNum,
      pageData: pageData,
      repository: widget.repository,
      selectedVerse: widget.selectedVerse,
      onVerseTap: widget.onVerseTap,
      onSurahTap: widget.onSurahTap,
    );
  }
}

class _PageContent extends StatelessWidget {
  final int pageNum;
  final _PageData pageData;
  final QuranRepository repository;
  final VerseModel? selectedVerse;
  final void Function(VerseModel) onVerseTap;
  final void Function(SurahModel) onSurahTap;

  const _PageContent({
    required this.pageNum,
    required this.pageData,
    required this.repository,
    required this.selectedVerse,
    required this.onVerseTap,
    required this.onSurahTap,
  });

  List<String?> _translationsForBlock(_SurahBlock block) {
    final lang = SettingsService.translationLanguage;
    if (lang == 'ar') return [];
    return block.verses.map((v) {
      final key = '${block.surah.id}:${v.verseNumber}';
      return repository.getTranslation(key, language: lang);
    }).toList();
  }

  String _arabicIndic(int n) {
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

  String _formatUiNumber(int n, bool useArabicIndic) {
    return useArabicIndic ? _arabicIndic(n) : n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = SettingsService.fontSize;
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final isRtl = locale == 'ar' || locale == 'ur';
    final useArabicIndic = isRtl;

    if (pageData.blocks.isEmpty) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: QuranRenderConfig.textScaler),
        child: Center(
          child: Text(
            '${l10n.page} ${_formatUiNumber(pageNum, useArabicIndic)}',
            style: TextStyle(
              fontFamily: QuranRenderConfig.fontFamily,
              fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
              fontSize: fontSize * 0.7,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final firstBlock = pageData.blocks.first;
    final firstSurah = firstBlock.surah;
    final firstVerse = firstBlock.verses.first;
    final hizb = ((firstVerse.hizbQuarter - 1) ~/ 4) + 1;
    final surahName = isRtl ? firstSurah.name : firstSurah.englishName;

    final children = <Widget>[
      const SizedBox(height: 8),
      Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Text(
          '${l10n.page} ${_formatUiNumber(pageNum, useArabicIndic)}  |  '
          '${l10n.juz} ${_formatUiNumber(firstVerse.juz, useArabicIndic)}  |  '
          '$surahName ${_formatUiNumber(firstSurah.id, useArabicIndic)}  |  '
          '${l10n.hizb} ${_formatUiNumber(hizb, useArabicIndic)}',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: fontSize * 0.7,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: 24),
    ];

    for (final block in pageData.blocks) {
      final surahStartsHere = block.verses.any((v) => v.verseNumber == 1);
      if (surahStartsHere) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SurahHeaderWidget(
              surah: block.surah,
              fontSize: fontSize,
              onTap: () => onSurahTap(block.surah),
            ),
          ),
        );
      }

      final blockTranslations = _translationsForBlock(block);

      children.add(
        AdaptiveQuranRenderer(
          displayMode: QuranDisplayMode.pageView,
          pageNumber: pageNum,
          verses: block.verses,
          surahId: block.surah.id,
          fontSize: fontSize,
          translations: blockTranslations,
          onVerseTap: onVerseTap,
          colors: colors,
          selectedVerse: selectedVerse,
        ),
      );
    }

    final sheetHeight = selectedVerse != null
        ? MediaQuery.of(context).size.height * 0.40
        : 0.0;
    children.add(SizedBox(height: 80 + sheetHeight));

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: QuranRenderConfig.textScaler),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ValueListenableBuilder<String>(
          valueListenable: SettingsService.translationLanguageNotifier,
          builder: (_, lang, _) => Column(children: children),
        ),
      ),
    );
  }
}

class _TafseerSheetV2 extends StatefulWidget {
  final VerseModel? selectedVerse;
  final String? tafseer;
  final String? translation;
  final String? qiraat;
  final ColorScheme colors;
  final VoidCallback onDismiss;
  final Future<void> Function() onPlaySingleVerse;
  final Future<void> Function() onPlayToEndOfSurah;

  const _TafseerSheetV2({
    required this.selectedVerse,
    required this.tafseer,
    this.translation,
    required this.qiraat,
    required this.colors,
    required this.onDismiss,
    required this.onPlaySingleVerse,
    required this.onPlayToEndOfSurah,
  });

  @override
  State<_TafseerSheetV2> createState() => _TafseerSheetV2State();
}

class _TafseerSheetV2State extends State<_TafseerSheetV2> {
  final _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        );
      },
      child: widget.selectedVerse != null
          ? NotificationListener<DraggableScrollableNotification>(
              onNotification: (notification) {
                if (notification.extent == notification.minExtent) {
                  widget.onDismiss();
                }
                return false;
              },
              child: DraggableScrollableSheet(
                key: ValueKey('sheet_${widget.selectedVerse!.id}'),
                controller: _sheetController,
                initialChildSize: 0.35,
                minChildSize: 0.15,
                maxChildSize: 0.85,
                snap: false,
                builder: (context, scrollController) {
                  final sheetBody = Container(
                    decoration: BoxDecoration(
                      color: GlassConfig.enableBlur
                          ? (widget.colors.brightness == Brightness.dark
                                ? Colors.black.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.25))
                          : widget.colors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDragHandle(context),
                        Expanded(
                          child: VerseDetailPanel(
                            key: ValueKey(widget.selectedVerse!.id),
                            verse: widget.selectedVerse!,
                            tafseer: widget.tafseer,
                            translation: widget.translation,
                            qiraat: widget.qiraat,
                            onPlaySingleVerse: widget.onPlaySingleVerse,
                            onPlayToEndOfSurah: widget.onPlayToEndOfSurah,
                            scrollController: scrollController,
                          ),
                        ),
                      ],
                    ),
                  );
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: GlassConfig.enableBlur
                        ? BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: sheetBody,
                          )
                        : sheetBody,
                  );
                },
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        final screenHeight = MediaQuery.of(context).size.height;
        final currentSize = _sheetController.size;
        final newSize = (currentSize - details.delta.dy / screenHeight)
            .clamp(0.15, 0.85);
        _sheetController.jumpTo(newSize);
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
