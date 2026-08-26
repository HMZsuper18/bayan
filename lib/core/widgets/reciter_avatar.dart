import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/reciter_model.dart';

enum ReciterAvatarBadge { none, download, downloaded, downloading }

class ReciterAvatar extends StatefulWidget {
  final ReciterModel reciter;
  final double size;
  final ReciterAvatarBadge badge;
  final double progress;
  final bool showPlayOverlay;
  final VoidCallback? onCancel;

  const ReciterAvatar({
    super.key,
    required this.reciter,
    required this.size,
    this.badge = ReciterAvatarBadge.none,
    this.progress = 0,
    this.showPlayOverlay = false,
    this.onCancel,
  });

  @override
  State<ReciterAvatar> createState() => _ReciterAvatarState();
}

class _ReciterAvatarState extends State<ReciterAvatar> {
  bool _imageFailed = false;

  String get _initials {
    final parts = widget.reciter.name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  void didUpdateWidget(covariant ReciterAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reciter.imageAsset != widget.reciter.imageAsset) {
      _imageFailed = false;
    }
  }

  Widget _buildFallback() {
    return Container(
      width: widget.size,
      height: widget.size,
      color: AppColors.surfaceGreen,
      alignment: Alignment.center,
      child: RegExp(r'^[A-Z\?]{1,2}$').hasMatch(_initials)
          ? Text(
              _initials,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: widget.size * 0.32,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            )
          : Icon(
              Icons.person_rounded,
              size: widget.size * 0.42,
              color: AppColors.primaryGreen,
            ),
    );
  }

  Widget _buildImage() {
    if (widget.reciter.imageAsset.isEmpty || _imageFailed) {
      return _buildFallback();
    }

    final isAsset = !widget.reciter.imageAsset.startsWith('http');
    return isAsset
        ? Image.asset(
            widget.reciter.imageAsset,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (!_imageFailed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _imageFailed = true);
                });
              }
              return _buildFallback();
            },
          )
        : Image.network(
            widget.reciter.imageAsset,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (!_imageFailed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _imageFailed = true);
                });
              }
              return _buildFallback();
            },
          );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    const badgeSize = 22.0;
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.creamWhite, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, size: 13, color: iconColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : AppColors.primaryGreen.withValues(alpha: 0.45);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(child: _buildImage()),
          if (widget.showPlayOverlay)
            ClipOval(
              child: Container(
                width: widget.size,
                height: widget.size,
                color: Colors.black.withValues(alpha: 0.32),
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.creamWhite,
                  size: widget.size * 0.48,
                ),
              ),
            ),
          // Subtle ring drawn above the image (and any play overlay) so the
          // avatar reads as a consistent design-system circle in every state.
          IgnorePointer(
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.5),
              ),
            ),
          ),
          if (widget.badge == ReciterAvatarBadge.downloading)
            Positioned.fill(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: widget.progress > 0 ? widget.progress : null,
                    strokeWidth: 2.5,
                    color: AppColors.primaryGreen,
                    backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                  ),
                  if (widget.onCancel != null)
                    GestureDetector(
                      onTap: widget.onCancel,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (widget.badge == ReciterAvatarBadge.download)
            Positioned(
              right: -1,
              bottom: -1,
              child: _buildStatusBadge(
                icon: Icons.cloud_download_outlined,
                backgroundColor: AppColors.creamWhite,
                iconColor: AppColors.primaryGreen,
              ),
            ),
          if (widget.badge == ReciterAvatarBadge.downloaded)
            Positioned(
              right: -1,
              bottom: -1,
              child: _buildStatusBadge(
                icon: Icons.check_rounded,
                backgroundColor: AppColors.primaryGreen,
                iconColor: AppColors.white,
              ),
            ),
        ],
      ),
    );
  }
}
