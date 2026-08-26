import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/reciter_avatar.dart';
import '../../../data/models/reciter_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_playback_service.dart';
import '../../../services/default_reciter_service.dart';
import '../../../services/reciter_store_service.dart';

/// Shows a blurred bottom sheet with information about [reciter] and a delete
/// button that removes all of the reciter's downloaded data.
///
/// Returns true when the reciter's data was deleted, false otherwise.
Future<bool> showReciterInfoSheet(
  BuildContext context, {
  required ReciterModel reciter,
  required String displayName,
  bool isDownloaded = false,
}) async {
  return (await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => _ReciterInfoSheet(
      reciter: reciter,
      displayName: displayName,
      isDownloaded: isDownloaded,
    ),
  )) ??
      false;
}

class _ReciterInfoSheet extends StatefulWidget {
  final ReciterModel reciter;
  final String displayName;
  final bool isDownloaded;

  const _ReciterInfoSheet({
    required this.reciter,
    required this.displayName,
    this.isDownloaded = false,
  });

  @override
  State<_ReciterInfoSheet> createState() => _ReciterInfoSheetState();
}

class _ReciterInfoSheetState extends State<_ReciterInfoSheet> {
  bool _deleting = false;

  String _localizedBio(AppLocalizations l10n, ReciterModel reciter) {
    switch (reciter.id) {
      case 'mishary': return l10n.reciterBio_mishary;
      case 'sudais': return l10n.reciterBio_sudais;
      case 'shuraim': return l10n.reciterBio_shuraim;
      case 'muaiqly': return l10n.reciterBio_muaiqly;
      case 'dosari': return l10n.reciterBio_dosari;
      case 'ajmi': return l10n.reciterBio_ajmi;
      case 'ghamdi': return l10n.reciterBio_ghamdi;
      case 'huthaify': return l10n.reciterBio_huthaify;
      case 'abdulbasit': return l10n.reciterBio_abdulbasit;
      case 'husary': return l10n.reciterBio_husary;
      case 'minshawi': return l10n.reciterBio_minshawi;
      case 'banna': return l10n.reciterBio_banna;
      case 'shatri': return l10n.reciterBio_shatri;
      case 'rifai': return l10n.reciterBio_rifai;
      case 'qasim': return l10n.reciterBio_qasim;
      case 'fares': return l10n.reciterBio_fares;
      case 'tunaiji': return l10n.reciterBio_tunaiji;
      default: return reciter.bio;
    }
  }

  String _localizedCategory(AppLocalizations l10n, String category) {
    switch (category) {
      case 'Makkah & Madinah Imams': return l10n.reciterCategoryMakkahMadinah;
      case 'Classic Egyptian Reciters': return l10n.reciterCategoryClassicEgyptian;
      case 'Hadr / Fast Recitation': return l10n.reciterCategoryHadrFast;
      default: return category;
    }
  }

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      final audio = AudioPlaybackService.instance;
      if (audio.currentState.reciter?.id == widget.reciter.id) {
        await audio.stop();
      }
      await ReciterStoreService.instance.clearReciterData(widget.reciter.id);
      if (DefaultReciterService.getDefaultReciterId() == widget.reciter.id) {
        await DefaultReciterService.clearDefaultReciter();
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.35);

    return Container(
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
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Center(
                    child: ReciterAvatar(
                      reciter: widget.reciter,
                      size: 96,
                      badge: widget.isDownloaded
                          ? ReciterAvatarBadge.downloaded
                          : ReciterAvatarBadge.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  if (widget.reciter.arabicName.isNotEmpty &&
                      widget.reciter.arabicName != widget.displayName) ...[
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        widget.reciter.arabicName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _InfoPill(
                        icon: Icons.category_outlined,
                        label: _localizedCategory(l10n, widget.reciter.category),
                      ),
                      if (widget.isDownloaded) ...[
                        const SizedBox(width: 8),
                        _InfoPill(
                          icon: Icons.check_circle_outline,
                          label: l10n.downloaded,
                          isDownloaded: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _localizedBio(l10n, widget.reciter),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      height: 1.6,
                      color: colors.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _deleting ? null : _delete,
                    child: GlassContainer(
                      borderRadius: 14,
                      blur: 6,
                      opacity: 0.12,
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_deleting)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.error,
                              ),
                            )
                          else
                            const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: AppColors.error,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.delete,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small rounded pill used to show the reciter's category and download
/// status in the info sheet.
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDownloaded;

  const _InfoPill({
    required this.icon,
    required this.label,
    this.isDownloaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDownloaded ? AppColors.primaryGreen : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
