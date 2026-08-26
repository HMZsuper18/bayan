import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/reciter_avatar.dart';
import '../../../../data/models/reciter_model.dart';
import '../../../../services/audio_playback_service.dart';
import '../../../../services/reciter_store_service.dart';
import '../../../reciters_store/presentation/reciter_info_sheet.dart';
import '../../bloc/dashboard_bloc.dart';

class RecitationsTray extends StatelessWidget {
  final List<ReciterModel> reciters;
  final Set<String> downloadingIds;
  final Map<String, double> downloadProgress;
  final VoidCallback onAddReciter;
  final ValueChanged<ReciterModel> onReciterTap;

  const RecitationsTray({
    super.key,
    required this.reciters,
    this.downloadingIds = const {},
    this.downloadProgress = const {},
    required this.onAddReciter,
    required this.onReciterTap,
  });

  static const double _baseAvatarSize = 56;
  static const double _baseItemWidth = 80;

  static double _scaleFactor(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1.0);

  static double _avatarSize(BuildContext context) =>
      _baseAvatarSize * _scaleFactor(context);

  static double _itemWidth(BuildContext context) =>
      _baseItemWidth * _scaleFactor(context);

  static double _listHeight(BuildContext context) =>
      _avatarSize(context) + 40 * _scaleFactor(context);

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GlassContainer(
      borderRadius: 16,
      blur: 8,
      opacity: 0.12,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.recitations,
            style: AppTextStyles.arabicTitle.copyWith(
              fontSize: 16,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _listHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: reciters.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == reciters.length) {
                  return _AddReciterButton(
                    label: l10n.addReciter,
                    onTap: onAddReciter,
                  );
                }

                final reciter = reciters[index];
                final isDownloading = downloadingIds.contains(reciter.id);
                final progress = downloadProgress[reciter.id] ?? 0;

                return _ReciterTrayItem(
                  reciter: reciter,
                  displayName: _reciterDisplayName(l10n, reciter),
                  isDownloading: isDownloading,
                  downloadProgress: progress,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReciterTrayItem extends StatelessWidget {
  final ReciterModel reciter;
  final String displayName;
  final bool isDownloading;
  final double downloadProgress;

  const _ReciterTrayItem({
    required this.reciter,
    required this.displayName,
    this.isDownloading = false,
    this.downloadProgress = 0,
  });

  ReciterAvatarBadge get _badge {
    if (isDownloading) return ReciterAvatarBadge.downloading;
    return ReciterAvatarBadge.none;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: AudioPlaybackService.instance.stateStream,
      initialData: AudioPlaybackService.instance.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final audioService = AudioPlaybackService.instance;
        final isCurrentReciter = state != null &&
            state.reciter?.id == reciter.id;

        return SizedBox(
          width: RecitationsTray._itemWidth(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (isDownloading) {
                    ReciterStoreService.instance.cancelDownload(reciter.id);
                    return;
                  }
                  if (isCurrentReciter) {
                    audioService.togglePlayPause();
                  } else {
                    audioService.playAllSurahs(reciter: reciter, startSurahId: 1);
                  }
                },
                onLongPress: isDownloading
                    ? null
                    : () async {
                        final deleted = await showReciterInfoSheet(
                          context,
                          reciter: reciter,
                          displayName: displayName,
                          isDownloaded: true,
                        );
                        if (deleted && context.mounted) {
                          context
                              .read<DashboardBloc>()
                              .add(const RefreshDownloadedReciters());
                        }
                      },
                child: Stack(
                  children: [
                    ReciterAvatar(
                      reciter: reciter,
                      size: RecitationsTray._avatarSize(context),
                      badge: _badge,
                      progress: downloadProgress,
                      showPlayOverlay: false,
                    ),
                    if (!isDownloading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.35),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.28)
                                  : AppColors.primaryGreen.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            isCurrentReciter && state.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppColors.creamWhite,
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isDownloading ? AppLocalizations.of(context)!.downloading : displayName,
                textAlign: TextAlign.center,
                style: AppTextStyles.englishBody.copyWith(
                  fontSize: 10,
                  height: 1.1,
                  color: isDownloading
                      ? AppColors.primaryGreen
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.85),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

}

class _AddReciterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddReciterButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = RecitationsTray._avatarSize(context);

    return SizedBox(
      width: RecitationsTray._itemWidth(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryGreen, width: 1.5),
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.englishBody.copyWith(
                fontSize: 10,
                height: 1.1,
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
