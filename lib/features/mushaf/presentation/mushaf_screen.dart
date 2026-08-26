import 'dart:async';
import 'dart:ui';
import 'package:bayan/core/utils/quran_render_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/mini_player.dart';
import '../../../data/database/hive_service.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/models/reciter_model.dart';
import '../../../data/models/surah_model.dart';
import '../../../data/models/verse_model.dart';
import '../../../data/database/settings_service.dart';
import '../../../data/database/quran_index.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_playback_service.dart';
import '../../../services/default_reciter_service.dart';
import '../../../services/reciter_store_service.dart';
import '../../settings/presentation/settings_screen.dart';
import 'widgets/adaptive_quran_renderer.dart';
import 'widgets/surah_header_widget.dart';
import 'widgets/verse_detail_panel.dart';
import 'widgets/surah_options_sheet.dart';
import 'widgets/bookmarks_sheet.dart';

class MushafScreen extends StatefulWidget {
  final int? initialSurahId;
  final int? initialVerseNumber;
  final int? openTafseerForVerseId;

  const MushafScreen({
    super.key,
    this.initialSurahId,
    this.initialVerseNumber,
    this.openTafseerForVerseId,
  });

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = (widget.initialSurahId ?? 1) - 1;
    _pageController = PageController(initialPage: _currentPage);
    _persistPosition();
  }

  /// Saves the current surah (and its starting page) as the last-read position
  /// so the dashboard "open mushaf" card resumes here in either layout.
  void _persistPosition() {
    final surahId = _currentPage + 1;
    SettingsService.lastMushafSurahId = surahId;
    SettingsService.lastMushafPage =
        QuranIndexService.instance.getSurahPage(surahId);
  }

  Widget _topBarIconButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return GlassContainer(
      borderRadius: 20,
      blur: 6,
      opacity: 0.08,
      padding: EdgeInsets.zero,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon),
        color: Theme.of(context).colorScheme.onSurface,
        onPressed: onPressed,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        body: Stack(
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: PageView.builder(
                controller: _pageController,
                itemCount: 114,
                reverse: false,
                onPageChanged: (page) {
                  _currentPage = page;
                  _persistPosition();
                },
                itemBuilder: (context, index) {
                  final surahId = index + 1;
                  return _SurahPage(
                    surahId: surahId,
                    initialVerseNumber: surahId == widget.initialSurahId
                        ? widget.initialVerseNumber
                        : null,
                    openTafseerForVerseId:
                        surahId == widget.initialSurahId
                            ? widget.openTafseerForVerseId
                            : null,
                    onSurahChanged: (newSurahId) {
                      if (_pageController.hasClients) {
                        _pageController.animateToPage(
                          newSurahId - 1,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    key: ValueKey(surahId),
                  );
                },
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _topBarIconButton(
                        context,
                        Icons.bookmark_border_rounded,
                        () => showBookmarksSheet(context),
                      ),
                      const SizedBox(width: 8),
                      _topBarIconButton(
                        context,
                        Icons.arrow_back_rounded,
                        () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
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
}

class _SurahPage extends StatefulWidget {
  final int surahId;
  final int? initialVerseNumber;
  final int? openTafseerForVerseId;
  final void Function(int surahId)? onSurahChanged;

  const _SurahPage({
    super.key,
    required this.surahId,
    this.initialVerseNumber,
    this.openTafseerForVerseId,
    this.onSurahChanged,
  });

  @override
  State<_SurahPage> createState() => _SurahPageState();
}

class _SurahPageState extends State<_SurahPage> {
  final _repository = QuranRepository();
  final _scrollController = ScrollController();
  final _audioService = AudioPlaybackService.instance;
  final _reciterStore = ReciterStoreService.instance;
  SurahModel? _surah;
  List<VerseModel> _verses = [];
  List<String?> _translations = [];
  VerseModel? _selectedVerse;
  String? _tafseer;
  String? _translation;
  String? _qiraat;
  int? _playingVerseNumber;
  List<ReciterModel> _downloadedReciters = [];
  StreamSubscription<PlaybackState>? _playbackSub;
  Timer? _verseSwitchTimer;

  @override
  void initState() {
    super.initState();
    _loadSurah();
    _loadReciters();
    _playbackSub = _audioService.stateStream.listen((state) {
      if (!mounted) return;
      if (state.surahId != widget.surahId && state.surahId != null) {
        widget.onSurahChanged?.call(state.surahId!);
        return;
      }
      final newVerse = state.surahId == widget.surahId ? state.currentVerseNumber : null;
      if (newVerse != _playingVerseNumber) {
        setState(() => _playingVerseNumber = newVerse);
        _scrollToVerse(newVerse ?? 1);
      }
    });
    if (widget.openTafseerForVerseId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final verse = HiveService.getVerse(widget.openTafseerForVerseId!);
        if (verse == null) return;
        final key = '${_surah!.id}:${verse.verseNumber}';
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
        _scrollToVerse(verse.verseNumber);
      });
    } else if (widget.initialVerseNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final verse = _verses.firstWhere(
          (v) => v.verseNumber == widget.initialVerseNumber,
          orElse: () => _verses.first,
        );
        setState(() => _selectedVerse = verse);
        _scrollToVerse(verse.verseNumber);
      });
    }
  }

  Future<void> _loadReciters() async {
    final reciters = await _reciterStore.getDownloadedReciters();
    if (mounted) setState(() => _downloadedReciters = reciters);
  }

  @override
  void didUpdateWidget(_SurahPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surahId != widget.surahId) {
      _loadSurah();
    }
  }

  @override
  void dispose() {
    _verseSwitchTimer?.cancel();
    _playbackSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadSurah() {
    _surah = _repository.getSurahById(widget.surahId);
    _verses = _repository.getVersesBySurah(widget.surahId);
    _selectedVerse = null;
    _tafseer = null;
    _translation = null;
    _qiraat = null;
    _playingVerseNumber = null;
    _loadTranslations();
  }

  void _loadTranslations() {
    final lang = SettingsService.translationLanguage;
    if (lang == 'ar') {
      _translations = [];
      return;
    }
    _translations = _verses.map((v) {
      final key = '${widget.surahId}:${v.verseNumber}';
      return _repository.getTranslation(key, language: lang);
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
    if (_surah == null) return const SizedBox.shrink();

    final fontSize = SettingsService.fontSize;
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final isRtl = locale == 'ar' || locale == 'ur';

    final sheetHeight = _selectedVerse != null
        ? MediaQuery.of(context).size.height * 0.40
        : 0.0;

    final isShortSurah = _verses.length <= 15;

    final surahContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_verses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Directionality(
              textDirection:
                  isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                '${l10n.juz} ${_formatUiNumber(_verses.first.juz, isRtl)}  |  '
                '${l10n.page} ${_formatUiNumber(_verses.first.page, isRtl)}',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: fontSize * 0.7,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        SurahHeaderWidget(
          surah: _surah!,
          fontSize: fontSize,
          onTap: () => _onSurahHeaderTap(_surah!),
        ),
        const SizedBox(height: 24),
        AdaptiveQuranRenderer(
          displayMode: QuranDisplayMode.surahView,
          verses: _verses,
          surahId: _surah!.id,
          fontSize: fontSize,
          onVerseTap: _onVerseTap,
          colors: colors,
          selectedVerse: _selectedVerse,
          playingVerseNumber: _playingVerseNumber,
          translations: _translations,
        ),
      ],
    );

    return Stack(
        children: [
          MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: QuranRenderConfig.textScaler),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.only(top: 60, bottom: 80 + sheetHeight),
              child: isShortSurah
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.of(context).size.height * 0.65,
                      ),
                      child: Center(child: surahContent),
                    )
                  : surahContent,
            ),
          ),
            _TafseerSheet(
            selectedVerse: _selectedVerse,
            tafseer: _tafseer,
            translation: _translation,
            qiraat: _qiraat,
            colors: colors,
            surahVersesCount: _verses.length,
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
        ],
      );
  }

  void _scrollToVerse(int verseNumber) {
    if (_verses.length <= 15) return;
    final targetIndex = _verses.indexWhere((v) => v.verseNumber == verseNumber);
    if (targetIndex < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      int totalChars = 0, charsBefore = 0;
      const basmalah =
          'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
      final hasBasmalah = _surah!.id != 9;
      if (hasBasmalah) {
        totalChars += basmalah.length + 2;
      }
      for (final v in _verses) {
        totalChars +=
            v.textUthmani.trimRight().length +
            1 +
            _arabicIndic(v.verseNumber).length +
            1;
      }
      if (hasBasmalah) {
        charsBefore += basmalah.length + 2;
      }
      for (int i = 0; i < targetIndex; i++) {
        charsBefore +=
            _verses[i].textUthmani.trimRight().length +
            1 +
            _arabicIndic(_verses[i].verseNumber).length +
            1;
      }
      final progress = totalChars > 0 ? charsBefore / totalChars : 0.0;
      final sheetOffset = _selectedVerse != null
          ? MediaQuery.of(context).size.height * 0.40
          : 0.0;
      final targetOffset =
          (progress * _scrollController.position.maxScrollExtent) - sheetOffset;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onVerseTap(VerseModel verse) {
    _verseSwitchTimer?.cancel();
    if (!mounted) return;
    if (_selectedVerse?.id == verse.id) {
      setState(() {
        _selectedVerse = null;
        _tafseer = null;
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
        _qiraat = null;
      });
      _verseSwitchTimer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        final key = '${_surah!.id}:${verse.verseNumber}';
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
        _scrollToVerse(verse.verseNumber);
      });
    } else {
      final key = '${_surah!.id}:${verse.verseNumber}';
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
      _scrollToVerse(verse.verseNumber);
    }
  }

  Future<void> _playSelectedVerse() async {
    final verse = _selectedVerse;
    if (verse == null) return;

    final (reciter, isValid, errorMessage) = DefaultReciterService.validateDefaultReciter();

    if (!isValid) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx)!.warning),
            content: Text(errorMessage ?? AppLocalizations.of(ctx)!.unknownError),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(ctx)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToSettingsReciterSection();
                },
                child: Text(AppLocalizations.of(ctx)!.settings),
              ),
            ],
          ),
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
    if (verse == null || _surah == null) return;

    final (reciter, isValid, errorMessage) = DefaultReciterService.validateDefaultReciter();

    if (!isValid) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx)!.warning),
            content: Text(errorMessage ?? AppLocalizations.of(ctx)!.unknownError),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(ctx)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToSettingsReciterSection();
                },
                child: Text(AppLocalizations.of(ctx)!.settings),
              ),
            ],
          ),
        );
      }
      return;
    }

    await _audioService.playFromVerseToEnd(
      surahId: _surah!.id,
      verseNumber: verse.verseNumber,
      reciter: reciter!,
    );
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
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx)!.warning),
            content: Text(errorMessage ?? AppLocalizations.of(ctx)!.unknownError),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(ctx)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToSettingsReciterSection();
                },
                child: Text(AppLocalizations.of(ctx)!.settings),
              ),
            ],
          ),
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

  void _navigateToSettingsReciterSection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }
}

class _TafseerSheet extends StatefulWidget {
  final VerseModel? selectedVerse;
  final String? tafseer;
  final String? qiraat;
  final ColorScheme colors;
  final int surahVersesCount;
  final VoidCallback onDismiss;
  final Future<void> Function() onPlaySingleVerse;
  final Future<void> Function() onPlayToEndOfSurah;

  final String? translation;

  const _TafseerSheet({
    required this.selectedVerse,
    required this.tafseer,
    required this.translation,
    required this.qiraat,
    required this.colors,
    required this.surahVersesCount,
    required this.onDismiss,
    required this.onPlaySingleVerse,
    required this.onPlayToEndOfSurah,
  });

  @override
  State<_TafseerSheet> createState() => _TafseerSheetState();
}

class _TafseerSheetState extends State<_TafseerSheet> {
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
                          child:                         VerseDetailPanel(
                            key: ValueKey(widget.selectedVerse!.id),
                            verse: widget.selectedVerse!,
                            tafseer: widget.tafseer,
                            translation: widget.translation,
                            qiraat: widget.qiraat,
                            onPlaySingleVerse: widget.onPlaySingleVerse,
                            onPlayToEndOfSurah: widget.onPlayToEndOfSurah,
                            surahVersesCount: widget.surahVersesCount,
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
