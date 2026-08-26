import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import '../../../data/models/search_result_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/mini_player.dart';
import '../../../data/database/settings_service.dart';
import '../../../data/models/prayer_time_model.dart';
import '../../../data/models/reciter_model.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/database/quran_index.dart';
import '../../../data/models/surah_model.dart';
import '../../quran_index/presentation/verse_picker_sheet.dart';
import '../bloc/dashboard_bloc.dart';
import 'widgets/ayah_of_week_card.dart';
import 'widgets/azkar_widget.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/prayer_times_widget.dart';
import 'widgets/primary_action_card.dart';
import 'widgets/recitations_tray.dart';
import 'widgets/active_downloads_card.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../mushaf/presentation/mushaf_navigation.dart';
import '../../reciters_store/presentation/reciters_store_page.dart';
import '../../mushaf/presentation/widgets/bookmarks_sheet.dart';
import '../../../services/reciter_store_service.dart';
import '../../../services/audio_playback_service.dart';

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
  final Set<String> _downloadingIds = {};
  final Map<String, double> _downloadProgress = {};
  Timer? _refreshTimer;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _downloadSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncActiveDownloads();
    _setupDownloadListener();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Uri? launchData;
      try {
        launchData = await HomeWidget.initiallyLaunchedFromHomeWidget();
      } catch (_) {
        launchData = null;
      }
      if (launchData?.toString() == 'bayan://location' && mounted) {
        _onLocationTap();
      } else {
        _maybeAutoUpdateLocation();
      }
    });
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

          // Delay refresh to ensure Hive is updated
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              context.read<DashboardBloc>().add(
                const RefreshDownloadedReciters(),
              );
            }
          });
        } else {
          setState(() {
            _downloadingIds.add(progress.reciterId);
            _downloadProgress[progress.reciterId] = progress.fraction;
          });
        }
      },
      onError: (e) {
        debugPrint('Download stream error: $e');
        // Reset state on error
        if (mounted) {
          setState(() {
            _downloadingIds.clear();
            _downloadProgress.clear();
          });
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Refresh downloads when returning to foreground
      _syncActiveDownloads();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.read<DashboardBloc>().add(const RefreshDownloadedReciters());
        }
      });
      _maybeAutoUpdateLocation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Force refresh when this widget becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _syncActiveDownloads();
        context.read<DashboardBloc>().add(const RefreshDownloadedReciters());
        _maybeAutoUpdateLocation();
      }
    });
  }

  void _syncActiveDownloads() {
    try {
      final active = ReciterStoreService.instance.activeDownloads;
      setState(() {
        _downloadingIds.clear();
        _downloadProgress.clear();
        for (final id in active) {
          _downloadingIds.add(id);
          _downloadProgress[id] = ReciterStoreService.instance
              .getDownloadProgress(id);
        }
      });
    } catch (e) {
      debugPrint('Error syncing active downloads: $e');
    }
  }

  /// The location refresh window (3 days).
  static const Duration _locationRefreshInterval = Duration(days: 3);

  bool _autoUpdatingLocation = false;

  /// Whether a GPS refresh is due: never updated before (fresh install or
  /// cleared data) and never asked, or last fix older than
  /// [_locationRefreshInterval].
  bool get _isLocationRefreshDue {
    final last = SettingsService.lastLocationUpdate;
    if (last != null) {
      return DateTime.now().difference(last) >= _locationRefreshInterval;
    }
    // Fresh install / cleared data: refresh once (the auto path may prompt),
    // but never again if the user already declined, to avoid nagging.
    return SettingsService.lastLocationAttempt == null;
  }

  /// Auto-refreshes the location when due. The very first open prompts for
  /// permission; regular 3-day refreshes are silent.
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

  /// Resolves a fresh GPS position, persists it, and refreshes the prayer
  /// times. In [quiet] mode (automatic refresh) a denied permission does not
  /// prompt the user and simply reports that no update happened.
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

    // Multiple refresh attempts to ensure state syncs
    _syncActiveDownloads();

    // First refresh immediately
    context.read<DashboardBloc>().add(const RefreshDownloadedReciters());

    // Second refresh after delay to catch Hive updates
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<DashboardBloc>().add(const RefreshDownloadedReciters());
      }
    });
  }

  void _onReciterTap(ReciterModel reciter) {
    final audioService = AudioPlaybackService.instance;
    final state = audioService.currentState;
    final isCurrentReciter = state.reciter?.id == reciter.id;
    if (isCurrentReciter) {
      audioService.togglePlayPause();
    } else {
      audioService.playAllSurahs(reciter: reciter, startSurahId: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassBackground(
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        l10n.appTitle,
                        style: AppTextStyles.arabicTitle.copyWith(
                          color: AppColors.primaryGreen,
                        ),
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
                          onPressed: () => showBookmarksSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
              BlocSelector<DashboardBloc, DashboardState, SearchResultModel>(
                selector: (s) => s.searchResult,
                builder: (context, searchResults) {
                  if (searchResults.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  final l10n = AppLocalizations.of(context)!;
                  final isRtl = Directionality.of(context) == TextDirection.rtl;
                  final tiles = <Widget>[];

                  // Surahs
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
                            color: AppColors.primaryGreen,
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              SliverToBoxAdapter(
                child:
                    BlocSelector<
                      DashboardBloc,
                      DashboardState,
                      List<PrayerTimeModel>
                    >(
                      selector: (s) => s.prayerTimes,
                      builder: (context, prayerTimes) => PrayerTimesWidget(
                        prayerTimes: prayerTimes,
                        locating: _locating,
                        onLocationTap: _onLocationTap,
                      ),
                    ),
              ),
              const SliverToBoxAdapter(child: PrimaryActionCard()),
              SliverToBoxAdapter(
                child:
                    BlocSelector<
                      DashboardBloc,
                      DashboardState,
                      List<PrayerTimeModel>
                    >(
                      selector: (s) => s.prayerTimes,
                      builder: (context, prayerTimes) => AyahOfWeekCard(
                        footer: AzkarWidget(
                          prayerTimes: prayerTimes,
                          embedded: true,
                        ),
                      ),
                    ),
              ),
              const SliverToBoxAdapter(child: ActiveDownloadsCard()),
              SliverToBoxAdapter(
                child:
                    BlocSelector<
                      DashboardBloc,
                      DashboardState,
                      List<ReciterModel>
                    >(
                      selector: (s) => s.reciters,
                      builder: (context, reciters) => RecitationsTray(
                        reciters: reciters,
                        downloadingIds: _downloadingIds,
                        downloadProgress: _downloadProgress,
                        onAddReciter: _openRecitersStore,
                        onReciterTap: _onReciterTap,
                      ),
                    ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }
}
