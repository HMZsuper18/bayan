import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import '../../../data/models/search_result_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_launch.dart';
import '../../../core/utils/responsive_spacing.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/mini_player.dart';
import '../../../data/database/hive_service.dart';
import '../../../data/database/settings_service.dart';
import '../../../data/models/prayer_time_model.dart';
import '../../../data/models/reciter_model.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/database/quran_index.dart';
import '../../../data/models/surah_model.dart';
import '../../quran_index/presentation/verse_picker_sheet.dart';
import '../bloc/dashboard_bloc.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/prayer_times_widget.dart';
import 'widgets/primary_action_card.dart';
import 'widgets/active_downloads_card.dart';
import 'widgets/ayah_of_week_card.dart';
import 'widgets/ayah_of_week_share.dart';
import 'widgets/azkar_widget.dart';
import 'widgets/azkar_share_sheet.dart';
import '../../../core/utils/azkar_time_logic.dart';
import 'widgets/recitations_tray.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../mushaf/presentation/mushaf_navigation.dart';
import '../../mushaf/presentation/mushaf_scanner_screen.dart';
import '../../reciters_store/presentation/reciters_store_page.dart';
import '../../mushaf/presentation/widgets/bookmarks_sheet.dart';
import '../../qiblah/presentation/qiblah_screen.dart';
import '../../../services/reciter_store_service.dart';
import '../../../services/audio_playback_service.dart';
import '../../../services/dhikr_widget_service.dart';
import '../../../services/ayah_of_week_service.dart';
import '../../../services/ayah_widget_service.dart';
import '../../../services/recitations_widget_service.dart';
import '../../../services/widget_control_handler.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DashboardBloc(repository: QuranRepository())
            ..add(const LoadDashboard()),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with WidgetsBindingObserver {
  bool _locating = false;
  Timer? _searchDebounce;
  StreamSubscription? _downloadSub;
  StreamSubscription<Uri?>? _widgetClickSub;
  final Set<String> _downloadingIds = {};
  final Map<String, double> _downloadProgress = {};
  Timer? _refreshTimer;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _downloadSub?.cancel();
    _widgetClickSub?.cancel();
    _refreshTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  bool _launchHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncActiveDownloads();
    _setupDownloadListener();

    // Cold start from a widget: [main] already captured the URI — handle
    // audio-only actions (play/toggle/cancel) synchronously here so playback
    // starts one frame earlier. Context-dependent URIs (store, scanner,
    // share, location) wait for the post-frame below.
    final early = WidgetLaunch.take();
    if (early != null) {
      final s = early.toString();
      if (s.startsWith('bayan://play/') ||
          s.startsWith('bayan://widget/')) {
        _launchHandled = true;
        _handleWidgetUri(s);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_launchHandled) return;
      Uri? launchData = early;
      if (launchData == null) {
        try {
          launchData = await HomeWidget.initiallyLaunchedFromHomeWidget();
        } catch (_) {
          launchData = null;
        }
      }
      if (!mounted) return;
      if (launchData != null) {
        _launchHandled = true;
        _handleWidgetUri(launchData.toString());
      } else {
        _maybeAutoUpdateLocation();
      }
    });
    // Warm start: app already alive when the widget is tapped — the plugin
    // delivers the URI through this stream instead of the initial intent.
    _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
      if (mounted && uri != null) _handleWidgetUri(uri.toString());
    });
  }

  void _handleWidgetUri(String uri) {
    if (uri == 'bayan://location') {
      _onLocationTap();
    } else if (uri == 'bayan://scanner') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MushafScannerScreen()),
      );
    } else if (uri == 'bayan://share/dhikr') {
      _shareDhikr();
    } else if (uri == 'bayan://share/ayah') {
      _shareAyah();
    } else if (uri.startsWith('bayan://play/')) {
      final reciterId = uri.replaceFirst('bayan://play/', '');
      _playReciterById(reciterId);
      _backgroundFromWidget();
    } else if (uri.startsWith('bayan://widget/toggle')) {
      AudioPlaybackService.instance.togglePlayPause();
      _backgroundFromWidget();
    } else if (uri.startsWith('bayan://widget/stop') ||
        uri.startsWith('bayan://widget/cancel')) {
      AudioPlaybackService.instance.stop();
      _backgroundFromWidget();
    } else if (uri.startsWith('bayan://store')) {
      _openRecitersStore();
    } else {
      _maybeAutoUpdateLocation();
    }
  }

  /// Widget actions were launched with `bayan_background_play`; hand control
  /// back to the launcher as soon as we've issued the action so the app
  /// doesn't sit in front waiting for a fixed timer.
  Future<void> _backgroundFromWidget() async {
    try {
      await const MethodChannel(
        'com.hamzah.bayan/app',
      ).invokeMethod('moveToBackground');
    } catch (_) {}
  }

  void _setupDownloadListener() {
    _downloadSub = ReciterStoreService.instance.progressStream.listen(
      (progress) {
        if (!mounted) return;

        if (progress.fraction >= 1.0) {
          setState(() {
            _downloadingIds.remove(progress.reciterId);
            _downloadProgress.remove(progress.reciterId);
          });
          // Newly downloaded reciters become eligible for the widget list.
          RecitationsWidgetService.refresh();
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              context
                  .read<DashboardBloc>()
                  .add(const RefreshDownloadedReciters());
            }
          });
        } else {
          setState(() {
            _downloadingIds.add(progress.reciterId);
            _downloadProgress[progress.reciterId] = progress.fraction;
          });
        }
      },
    );
  }

  void _syncActiveDownloads() {
    final activeIds = ReciterStoreService.instance.activeDownloads;
    for (final id in activeIds) {
      _downloadingIds.add(id);
    }
  }

  bool get _isLocationRefreshDue {
    final last = SettingsService.lastLocationAttempt;
    if (last == null) return true;
    return DateTime.now().difference(last).inMinutes > 30;
  }

  bool _autoUpdatingLocation = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) _maybeAutoUpdateLocation();
      });
    }
  }

  Future<bool> _maybeAutoUpdateLocation() async {
    if (_autoUpdatingLocation) return false;
    if (!_isLocationRefreshDue || !mounted) return false;
    _autoUpdatingLocation = true;
    try {
      final isFirstOpen = SettingsService.lastLocationUpdate == null;
      return await _updateLocation(quiet: !isFirstOpen);
    } finally {
      _autoUpdatingLocation = false;
    }
  }

  Future<void> _onLocationTap() async {
    setState(() => _locating = true);
    await _updateLocation();
    if (mounted) setState(() => _locating = false);
  }

  Future<bool> _updateLocation({bool quiet = false}) async {
    SettingsService.lastLocationAttempt = DateTime.now();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (quiet) return false;
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return false;
        }
        permission = requested;
      }
      if (permission == LocationPermission.deniedForever) return false;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      SettingsService.latitude = position.latitude;
      SettingsService.longitude = position.longitude;
      SettingsService.lastLocationUpdate = DateTime.now();
      if (!mounted) return false;
      context.read<DashboardBloc>().add(
        UpdatePrayerTimes(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _pushOnNextFrame(BuildContext ctx, Widget page) {
    MushafNavigation.openOnNextFrame(ctx, page);
  }

  Future<void> _onSurahLongPress(BuildContext ctx, SurahModel surah) async {
    final verseNum = await showVersePicker(ctx, surah);
    if (verseNum == null || !ctx.mounted) return;
    _pushOnNextFrame(
      ctx,
      MushafNavigation.forSurah(surah.id, verseNumber: verseNum),
    );
  }

  Future<void> _openRecitersStore() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RecitersStorePage()));

    if (!mounted) return;
    _syncActiveDownloads();
    context.read<DashboardBloc>().add(const RefreshDownloadedReciters());
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<DashboardBloc>().add(const RefreshDownloadedReciters());
      }
    });
    RecitationsWidgetService.refresh();
  }

  void _onReciterTap(ReciterModel reciter) {
    final audioService = AudioPlaybackService.instance;
    final state = audioService.currentState;
    final isCurrentReciter = state.reciter?.id == reciter.id;
    if (isCurrentReciter) {
      audioService.togglePlayPause();
    } else {
      audioService.playAllSurahs(reciter: reciter, startSurahId: 1);
      RecitationsWidgetService.update(
        lastPlayedReciterId: reciter.id,
        lastPlayedReciterName: reciter.arabicName,
      );
    }
  }

  /// Whole-widget tap on the home-screen dhikr widget. On Friday (Kahf
  /// window) it opens Surat Al-Kahf in the mushaf; otherwise it opens the
  /// azkar share sheet — recomputing the current item so a slightly stale
  /// widget still shows the right content.
  Future<void> _shareDhikr() async {
    final now = DateTime.now();
    final prayerTimes = context.read<DashboardBloc>().state.prayerTimes;
    final type = getAzkarType(now, prayerTimes: prayerTimes);
    if (!mounted) return;
    if (type == AzkarWidgetType.kahf) {
      unawaited(MushafNavigation.open(context, MushafNavigation.forSurah(18)));
      return;
    }
    final item = getAzkarItem(type, now);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AzkarShareSheet(item: item, type: type),
    );
    if (mounted) DhikrWidgetService.update(type: type, item: item);
  }

  Future<void> _shareAyah() async {
    final verse = AyahOfWeekService.verse;
    final surah = verse == null
        ? null
        : HiveService.surahsBox.get(verse.surahId);
    if (verse == null || surah == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AyahOfWeekShareSheet(verse: verse, surah: surah),
    );
    if (mounted) AyahWidgetService.update();
  }

  void _playReciterById(String reciterId) {
    WidgetControlHandler.playReciter(reciterId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassBackground(
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                reverse: true,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildMainPage(l10n),
                  _buildSecondaryPage(l10n),
                ],
              ),
              // Swipe hint arrow
              if (_currentPage == 0)
                PositionedDirectional(
                  start: 12,
                  bottom: 100,
                  child: _SwipeHintArrow(),
                ),
            ],
          ),
        ),
        floatingActionButton: _buildQiblahFab(),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }

  Widget _buildMainPage(AppLocalizations l10n) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.horizontalPadding(context),
              12,
              AppSpacing.horizontalPadding(context),
              4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GlassContainer(
                  borderRadius: 20,
                  blur: 6,
                  opacity: 0.08,
                  padding: EdgeInsets.zero,
                  width: 40,
                  height: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: l10n.settings,
                    onPressed: () {
                      final bloc = context.read<DashboardBloc>();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ).then((_) {
                        if (mounted) {
                          bloc.add(const LoadDashboard());
                        }
                      });
                    },
                  ),
                ),
                Text(
                  l10n.appTitle,
                  style: AppTextStyles.arabicTitle.copyWith(
                    color: AppColors.primaryGreenOf(context),
                  ),
                  maxLines: 1,
                ),
                GlassContainer(
                  borderRadius: 20,
                  blur: 6,
                  opacity: 0.08,
                  padding: EdgeInsets.zero,
                  width: 40,
                  height: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.bookmark_border_rounded),
                    tooltip: l10n.bookmarks,
                    onPressed: () => showBookmarksSheet(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Search bar with hijri calendar icon
        SliverToBoxAdapter(
          child: BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              return SearchBarWidget(
                onSearch: (query) {
                  context.read<DashboardBloc>().add(
                    SearchDashboard(query),
                  );
                },
                onClear: () {
                  context.read<DashboardBloc>().add(
                    const LoadDashboard(),
                  );
                },
              );
            },
          ),
        ),
        // Search results
        BlocSelector<DashboardBloc, DashboardState, SearchResultModel>(
          selector: (s) => s.searchResult,
          builder: (context, searchResults) {
            if (searchResults.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }

            final isRtl = Directionality.of(context) == TextDirection.rtl;
            final tiles = <Widget>[];

            for (final s in searchResults.surahs) {
              final revelationLabel = s.revelationType == 'Makkah'
                  ? l10n.makkah
                  : l10n.madinah;
              final name = isRtl ? s.name : s.englishName;
              tiles.add(
                GestureDetector(
                  onLongPress: () => _onSurahLongPress(context, s),
                  child: ListTile(
                    leading: Icon(
                      Icons.book_outlined,
                      color: AppColors.primaryGreenOf(context),
                    ),
                    title: Directionality(
                      textDirection: isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Text(
                        '${l10n.surah} $name (${s.id})',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    subtitle: Directionality(
                      textDirection: isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Text(
                        '$name ($revelationLabel) • ${s.versesCount} ${l10n.verses} • ${l10n.page} ${QuranIndexService.instance.getSurahPage(s.id)}',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    onTap: () {
                      MushafNavigation.open(
                        context,
                        MushafNavigation.forSurah(s.id),
                      );
                    },
                  ),
                ),
              );
            }

            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.horizontalPadding(context),
                ),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: tiles,
                  ),
                ),
              ),
            );
          },
        ),
        // Prayer times
        SliverToBoxAdapter(
          child: BlocSelector<DashboardBloc, DashboardState, List<PrayerTimeModel>>(
            selector: (s) => s.prayerTimes,
            builder: (context, prayerTimes) => PrayerTimesWidget(
              prayerTimes: prayerTimes,
              locating: _locating,
              onLocationTap: _onLocationTap,
            ),
          ),
        ),
        // Quick action row: Hijri calendar + Mushaf card
        const SliverToBoxAdapter(child: PrimaryActionCard()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildSecondaryPage(AppLocalizations l10n) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        // Ayah of the week + Azkar
        SliverToBoxAdapter(
          child: BlocSelector<DashboardBloc, DashboardState, List<PrayerTimeModel>>(
            selector: (s) => s.prayerTimes,
            builder: (context, prayerTimes) => _buildAyahAzkarCard(context, prayerTimes),
          ),
        ),
        const SliverToBoxAdapter(child: ActiveDownloadsCard()),
        // Recitations tray
        SliverToBoxAdapter(
          child: BlocSelector<DashboardBloc, DashboardState, List<ReciterModel>>(
            selector: (s) => s.reciters,
            builder: (context, reciters) => _buildRecitationsTray(context, reciters),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildAyahAzkarCard(BuildContext context, List<PrayerTimeModel> prayerTimes) {
    // Lazy import to avoid circular deps
    try {
      return _AyahAzkarSection(
        prayerTimes: prayerTimes,
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildRecitationsTray(BuildContext context, List<ReciterModel> reciters) {
    try {
      return _RecitationsTraySection(
        reciters: reciters,
        downloadingIds: _downloadingIds,
        downloadProgress: _downloadProgress,
        onAddReciter: _openRecitersStore,
        onReciterTap: _onReciterTap,
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget? _buildQiblahFab() {
    final accent = AppColors.primaryGreenOf(context);
    return FloatingActionButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QiblahScreen()),
        );
      },
      tooltip: AppLocalizations.of(context)!.qiblah,
      backgroundColor: accent,
      heroTag: 'qiblah_fab',
      child: const Icon(Icons.explore_rounded, color: Colors.white),
    );
  }
}

class _SwipeHintArrow extends StatefulWidget {
  @override
  State<_SwipeHintArrow> createState() => _SwipeHintArrowState();
}

class _SwipeHintArrowState extends State<_SwipeHintArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : AppColors.primaryGreenOf(context).withValues(alpha: 0.3);

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final offset = isRtl ? _animation.value : -_animation.value;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, color: color, size: 28),
          Icon(isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, color: color, size: 28),
        ],
      ),
    );
  }
}

/// Lazy-loaded ayah/azkar section for the secondary page
class _AyahAzkarSection extends StatelessWidget {
  final List<PrayerTimeModel> prayerTimes;
  const _AyahAzkarSection({required this.prayerTimes});

  @override
  Widget build(BuildContext context) {
    // Import at file level via the dashboard_screen imports
    final ayahCard = AyahOfWeekCard(
      footer: AzkarWidget(
        prayerTimes: prayerTimes,
        embedded: true,
      ),
    );
    return ayahCard;
  }
}

/// Lazy-loaded recitations tray for the secondary page
class _RecitationsTraySection extends StatelessWidget {
  final List<ReciterModel> reciters;
  final Set<String> downloadingIds;
  final Map<String, double> downloadProgress;
  final VoidCallback onAddReciter;
  final ValueChanged<ReciterModel> onReciterTap;

  const _RecitationsTraySection({
    required this.reciters,
    required this.downloadingIds,
    required this.downloadProgress,
    required this.onAddReciter,
    required this.onReciterTap,
  });

  @override
  Widget build(BuildContext context) {
    return RecitationsTray(
      reciters: reciters,
      downloadingIds: downloadingIds,
      downloadProgress: downloadProgress,
      onAddReciter: onAddReciter,
      onReciterTap: onReciterTap,
    );
  }
}
