import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/database/hive_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_playback_service.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  final _audioService = AudioPlaybackService.instance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<PlaybackState>(
      stream: _audioService.stateStream,
      initialData: _audioService.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null || state.isEmpty) return const SizedBox.shrink();

        final surah = state.surahId != null
            ? HiveService.surahsBox.get(state.surahId!)
            : null;
        final surahName = surah?.name ?? '';
        final surahEnglish = surah?.englishName ?? '';
        final verseLabel = state.currentVerseNumber != null
            ? '${l10n.verse} ${state.currentVerseNumber}'
            : '';

        final progress = state.duration.inMilliseconds > 0
            ? state.position.inMilliseconds / state.duration.inMilliseconds
            : 0.0;

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(AppColors.primaryGreen),
                      minHeight: 2,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: AppColors.primaryGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  surahName,
                                  style: AppTextStyles.arabicTitle.copyWith(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (surahEnglish.isNotEmpty)
                                  Text(
                                    '$surahEnglish${verseLabel.isNotEmpty ? ' - $verseLabel' : ''}',
                                    style: AppTextStyles.englishBody.copyWith(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (state.isLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryGreen,
                              ),
                            )
                          else ...[
                            IconButton(
                              icon: Icon(
                                state.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                color: AppColors.primaryGreen,
                                size: 34,
                              ),
                              onPressed: _audioService.togglePlayPause,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.stop_circle_rounded,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                size: 26,
                              ),
                              onPressed: _audioService.stop,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
