import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bayan/l10n/app_localizations.dart';
import 'package:bayan/core/theme/app_colors.dart';
import 'package:bayan/core/theme/app_text_styles.dart';
import 'package:bayan/core/widgets/glass_container.dart';
import 'package:bayan/core/widgets/reciter_avatar.dart';
import 'package:bayan/core/utils/reciter_utils.dart';
import 'package:bayan/data/models/reciter_model.dart';
import 'package:bayan/data/database/hive_service.dart';
import 'package:bayan/services/default_reciter_service.dart';
import 'package:bayan/services/reciter_store_service.dart';
import 'package:bayan/services/hybrid_download_service.dart';
import 'reciter_info_sheet.dart';

const _categoryOrder = [
  'Makkah & Madinah Imams',
  'Classic Egyptian Reciters',
  'Hadr / Fast Recitation',
];

class RecitersStorePage extends StatefulWidget {
  const RecitersStorePage({super.key});

  @override
  State<RecitersStorePage> createState() => _RecitersStorePageState();
}

class _RecitersStorePageState extends State<RecitersStorePage> {
  final _service = ReciterStoreService.instance;
  Set<String> _downloadedIds = {};
  final Set<String> _downloadingIds = {};
  final Map<String, double> _progress = {};
  final Map<String, String> _statusMessages = {};
  StreamSubscription<DownloadProgress>? _sub;
  StreamSubscription<Map<String, String>>? _statusSub;

  @override
  void initState() {
    super.initState();
    _loadDownloaded();
    _syncActiveDownloads();
    _sub = _service.progressStream.listen((p) {
      if (!mounted) return;
      debugPrint('📊 Progress - ${p.reciterId}: ${(p.fraction * 100).toStringAsFixed(1)}%');
      setState(() {
        _progress[p.reciterId] = p.fraction;
      });
    });
    _statusSub = _service.statusStream.listen((msg) {
      if (!mounted) return;
      msg.forEach((id, text) {
        setState(() => _statusMessages[id] = text);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDownloaded() async {
    try {
      final ids = await _service.getDownloadedReciterIds();
      if (mounted) {
        setState(() => _downloadedIds = ids);
      }
    } catch (e) {
      debugPrint('Error loading downloaded: $e');
    }
  }

  void _syncActiveDownloads() {
    try {
      final active = _service.activeDownloads;
      if (active.isEmpty) return;
      setState(() {
        for (final id in active) {
          _downloadingIds.add(id);
          _progress[id] = _service.getDownloadProgress(id);
        }
      });
    } catch (e) {
      debugPrint('Error syncing active downloads: $e');
    }
  }

  Future<void> _download(ReciterModel reciter) async {
    if (mounted) {
      setState(() {
        _downloadingIds.add(reciter.id);
        _downloadedIds.remove(reciter.id);
        _progress[reciter.id] = 0;
      });
    }

    HybridDownloadService.instance.startDownload(reciter);

    try {
      await _service.downloadReciter(reciter);

      if (!mounted || !_downloadingIds.contains(reciter.id)) return;

      final downloadedIds = await _service.getDownloadedReciterIds();
      final isActuallyDownloaded = downloadedIds.contains(reciter.id);

      if (!mounted || !_downloadingIds.contains(reciter.id)) return;

      debugPrint('🔍 Verification for ${reciter.id}: isActuallyDownloaded=$isActuallyDownloaded');

      if (mounted) {
        setState(() {
          _downloadingIds.remove(reciter.id);
          _progress.remove(reciter.id);
          if (isActuallyDownloaded) {
            _downloadedIds.add(reciter.id);
          } else {
            _downloadedIds.remove(reciter.id);
          }
        });
        if (isActuallyDownloaded &&
            DefaultReciterService.getDefaultReciterId() == null) {
          await DefaultReciterService.setDefaultReciterId(reciter.id);
        }
        if (!isActuallyDownloaded && mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.downloadIncomplete(reciter.name))),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Download failed for ${reciter.id} (${reciter.name}): $e');
      _service.cancelDownload(reciter.id);
      if (mounted) {
        setState(() {
          _downloadingIds.remove(reciter.id);
          _progress.remove(reciter.id);
          _downloadedIds.remove(reciter.id);
          _statusMessages.remove(reciter.id);
        });
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.downloadFailed(reciter.name))),
        );
      }
    }
  }

  Future<void> _cancelDownload(ReciterModel reciter) async {
    try {
      HybridDownloadService.instance.cancelDownload(reciter.id);
      if (mounted) {
        setState(() {
          _downloadingIds.remove(reciter.id);
          _progress.remove(reciter.id);
          _statusMessages.remove(reciter.id);
        });
      }
    } catch (e) {
      debugPrint('Error cancelling download: $e');
    }
  }

  Future<void> _showReciterInfo(ReciterModel reciter) async {
    final l10n = AppLocalizations.of(context)!;
    final deleted = await showReciterInfoSheet(
      context,
      reciter: reciter,
      displayName: reciterDisplayName(l10n, reciter),
      isDownloaded: _downloadedIds.contains(reciter.id),
    );
    if (deleted && mounted) {
      setState(() => _downloadedIds.remove(reciter.id));
    }
  }

  int _crossAxisCount(double width) {
    if (width >= 1000) return 5;
    if (width >= 720) return 4;
    if (width >= 480) return 3;
    return 2;
  }

  double _scaleFactor(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1.0);

  double _avatarSize(BuildContext context, double width) {
    final scale = _scaleFactor(context);
    final base = width >= 720 ? 84.0 : (width >= 480 ? 76.0 : 68.0);
    return base * scale;
  }

  List<MapEntry<String, List<ReciterModel>>> _orderedCategories(
    List<ReciterModel> allReciters,
  ) {
    final categorized = <String, List<ReciterModel>>{};
    for (final reciter in allReciters) {
      categorized.putIfAbsent(reciter.category, () => []).add(reciter);
    }

    final ordered = <MapEntry<String, List<ReciterModel>>>[];
    for (final category in _categoryOrder) {
      final reciters = categorized.remove(category);
      if (reciters != null && reciters.isNotEmpty) {
        ordered.add(MapEntry(category, reciters));
      }
    }
    ordered.addAll(categorized.entries);
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarColor = isDark
        ? const Color(0xFFE8E8E0)
        : AppColors.primaryGreen;
    final allReciters = HiveService.getAllReciters();
    final categories = _orderedCategories(allReciters);

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            l10n.recitersStore,
            style: AppTextStyles.arabicTitle.copyWith(
              color: appBarColor,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: appBarColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.sizeOf(context).width;
            final scale = _scaleFactor(context);
            final crossAxisCount = _crossAxisCount(screenWidth);
            final avatarSize = _avatarSize(context, screenWidth);
            final horizontalPadding = screenWidth >= 600 ? 24.0 : 16.0;
            final gridItemHeight = avatarSize + 48 * scale;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CustomScrollView(
                  slivers: [
                    for (final entry in categories) ...[
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _CategoryHeader(
                            title: _localizedCategory(l10n, entry.key),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          20,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12 * scale,
                            mainAxisSpacing: 16 * scale,
                            mainAxisExtent: gridItemHeight,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final reciter = entry.value[index];
                              final isDownloaded =
                                  _downloadedIds.contains(reciter.id);
                              final isDownloading =
                                  _downloadingIds.contains(reciter.id);

                              final status = _statusMessages[reciter.id];

                              return _ReciterStoreItem(
                                reciter: reciter,
                                avatarSize: avatarSize,
                                isDownloaded: isDownloaded,
                                isDownloading: isDownloading,
                                progress: _progress[reciter.id] ?? 0,
                                statusMessage: status,
                                onDownload: isDownloading 
                                    ? null 
                                    : () => _download(reciter),
                                onCancel: isDownloading
                                    ? () => _cancelDownload(reciter)
                                    : null,
                                onLongPress: isDownloading
                                    ? null
                                    : () => _showReciterInfo(reciter),
                                downloadedLabel: l10n.downloaded,
                                downloadingLabel: l10n.downloading,
                                displayName: reciterDisplayName(l10n, reciter),
                              );
                            },
                            childCount: entry.value.length,
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _localizedCategory(AppLocalizations l10n, String category) {
    switch (category) {
      case 'Makkah & Madinah Imams':
        return l10n.reciterCategoryMakkahMadinah;
      case 'Classic Egyptian Reciters':
        return l10n.reciterCategoryClassicEgyptian;
      case 'Hadr / Fast Recitation':
        return l10n.reciterCategoryHadrFast;
      default:
        return category;
    }
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;

  const _CategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.englishSubtitle.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
        ),
      ],
    );
  }
}

class _ReciterStoreItem extends StatelessWidget {
  final ReciterModel reciter;
  final double avatarSize;
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;
  final String? statusMessage;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onLongPress;
  final String downloadedLabel;
  final String downloadingLabel;
  final String displayName;

  const _ReciterStoreItem({
    required this.reciter,
    required this.avatarSize,
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
    this.statusMessage,
    this.onDownload,
    this.onCancel,
    this.onLongPress,
    required this.downloadedLabel,
    required this.downloadingLabel,
    required this.displayName,
  });

  ReciterAvatarBadge get _badge {
    if (isDownloading) return ReciterAvatarBadge.downloading;
    if (isDownloaded) return ReciterAvatarBadge.downloaded;
    return ReciterAvatarBadge.download;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isDownloading
          ? downloadingLabel
          : isDownloaded
              ? downloadedLabel
              : displayName,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isDownloading ? null : onDownload,
        onLongPress: isDownloading ? null : onLongPress,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ReciterAvatar(
              reciter: reciter,
              size: avatarSize,
              badge: _badge,
              progress: progress,
              onCancel: isDownloading ? onCancel : null,
            ),
            SizedBox(height: 8 * MediaQuery.textScalerOf(context).scale(1.0)),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: AppTextStyles.englishBody.copyWith(
                fontSize: 11,
                height: 1.2,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (statusMessage != null && isDownloading)
              Padding(
                padding: EdgeInsets.only(top: 2 * MediaQuery.textScalerOf(context).scale(1.0)),
                child: Text(
                  statusMessage!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.englishBody.copyWith(
                    fontSize: 8,
                    height: 1.1,
                    color: AppColors.primaryGreen.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
