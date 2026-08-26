import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/reciter_avatar.dart';
import '../../../../data/database/hive_service.dart';
import '../../../../data/models/reciter_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/reciter_store_service.dart';

/// Dashboard card listing every reciter currently downloading (including ones
/// started from the Reciters Store and still running in the background). Each
/// row shows live byte-based progress and a cancel action. Hidden when no
/// download is active.
class ActiveDownloadsCard extends StatefulWidget {
  const ActiveDownloadsCard({super.key});

  @override
  State<ActiveDownloadsCard> createState() => _ActiveDownloadsCardState();
}

class _ActiveDownloadsCardState extends State<ActiveDownloadsCard> {
  final _service = ReciterStoreService.instance;
  StreamSubscription<DownloadProgress>? _progressSub;
  StreamSubscription<Set<String>>? _activeSub;
  final Set<String> _downloading = {};
  final Map<String, double> _progress = {};
  Map<String, ReciterModel>? _reciterLookup;

  Map<String, ReciterModel> get _reciters {
    return _reciterLookup ??= {
      for (final r in HiveService.getAllReciters()) r.id: r,
    };
  }

  @override
  void initState() {
    super.initState();
    _activeSub = _service.activeStream.listen(_onActiveChanged);
    _progressSub = _service.progressStream.listen(_onProgress);
    _onActiveChanged(_service.activeDownloads);
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  void _onActiveChanged(Set<String> activeIds) {
    if (!mounted) return;
    setState(() {
      _downloading
        ..clear()
        ..addAll(activeIds);
      _progress.removeWhere((id, _) => !_downloading.contains(id));
      for (final id in _downloading) {
        _progress.putIfAbsent(id, () => _service.getDownloadProgress(id));
      }
    });
  }

  void _onProgress(DownloadProgress p) {
    if (!mounted) return;
    setState(() {
      if (p.fraction >= 1.0) {
        _downloading.remove(p.reciterId);
        _progress.remove(p.reciterId);
      } else if (_service.isDownloading(p.reciterId)) {
        _downloading.add(p.reciterId);
        _progress[p.reciterId] = p.fraction;
      }
    });
  }

  String _displayName(ReciterModel r) =>
      r.arabicName.isNotEmpty ? r.arabicName : r.name;

  @override
  Widget build(BuildContext context) {
    if (_downloading.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final ids = _downloading.toList();

    return GlassContainer(
      borderRadius: 16,
      blur: 8,
      opacity: 0.12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.download_rounded,
                size: 18,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.downloading,
                style: AppTextStyles.arabicTitle.copyWith(
                  fontSize: 16,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final id in ids) _buildItem(id),
        ],
      ),
    );
  }

  Widget _buildItem(String id) {
    final colors = Theme.of(context).colorScheme;
    final reciter = _reciters[id];
    final progress = (_progress[id] ?? 0.0).clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (reciter != null)
            ReciterAvatar(
              reciter: reciter,
              size: 40,
              badge: ReciterAvatarBadge.downloading,
              progress: progress,
              showPlayOverlay: false,
            )
          else
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reciter != null ? _displayName(reciter) : id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.englishBody.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      style: AppTextStyles.englishBody.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: colors.onSurface.withValues(alpha: 0.1),
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: colors.onSurface.withValues(alpha: 0.6),
            onPressed: () => _service.cancelDownload(id),
            tooltip: AppLocalizations.of(context)!.cancel,
          ),
        ],
      ),
    );
  }
}
