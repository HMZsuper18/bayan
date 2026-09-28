import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/wallpaper_service.dart';
import '../domain/crop_math.dart';

/// Pan/zoom crop step shown before a wallpaper is applied.
///
/// The viewport always has the exact device screen aspect ratio, so the user
/// sees precisely what Android will display — after cropping, the OS performs
/// no further cropping because bitmap and screen ratios already match.
class WallpaperCropScreen extends StatefulWidget {
  const WallpaperCropScreen({
    super.key,
    required this.imagePath,
    required this.title,
  });

  final String imagePath;
  final String title;

  @override
  State<WallpaperCropScreen> createState() => _WallpaperCropScreenState();
}

class _WallpaperCropScreenState extends State<WallpaperCropScreen> {
  Size? _imgSize;
  bool _decodeFailed = false;
  bool _busy = false;

  double _scale = 0;
  Offset _offset = Offset.zero;
  double _startScale = 0;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;
  Size? _vp;

  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _readImageSize();
  }

  Future<void> _readImageSize() async {
    final stream = Image.file(
      File(widget.imagePath),
    ).image.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!mounted) return;
        setState(() {
          _imgSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        if (mounted) setState(() => _decodeFailed = true);
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    super.dispose();
  }

  double _minScale(double vpW, double vpH) {
    final img = _imgSize!;
    return CropMath.coverScale(
      imgW: img.width,
      imgH: img.height,
      vpW: vpW,
      vpH: vpH,
    );
  }

  /// Initializes/resets the view when the viewport size changes (first layout
  /// or rotation): start at cover scale, centered.
  void _ensureView(double vpW, double vpH) {
    final changed = _vp == null || _vp!.width != vpW || _vp!.height != vpH;
    if (!changed) return;
    _vp = Size(vpW, vpH);
    final img = _imgSize!;
    _scale = _minScale(vpW, vpH);
    final dispW = img.width * _scale;
    final dispH = img.height * _scale;
    _offset = CropMath.clampOffset(
      offset: Offset((vpW - dispW) / 2, (vpH - dispH) / 2),
      dispW: dispW,
      dispH: dispH,
      vpW: vpW,
      vpH: vpH,
    );
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double vpW, double vpH) {
    final img = _imgSize!;
    final minS = _minScale(vpW, vpH);
    final s1 = (_startScale * d.scale).clamp(minS, minS * 4).toDouble();
    if (_startScale <= 0) return;
    // Image point under the finger when the gesture started stays anchored.
    final imgPt = Offset(
      (_startFocal.dx - _startOffset.dx) / _startScale,
      (_startFocal.dy - _startOffset.dy) / _startScale,
    );
    final f = d.localFocalPoint;
    final raw = Offset(f.dx - imgPt.dx * s1, f.dy - imgPt.dy * s1);
    final clamped = CropMath.clampOffset(
      offset: raw,
      dispW: img.width * s1,
      dispH: img.height * s1,
      vpW: vpW,
      vpH: vpH,
    );
    setState(() {
      _scale = s1;
      _offset = clamped;
    });
  }

  Future<void> _apply(double vpW, double vpH) async {
    if (_busy || _imgSize == null) return;
    setState(() => _busy = true);
    try {
      final rect = CropMath.cropRect(
        imgW: _imgSize!.width,
        imgH: _imgSize!.height,
        vpW: vpW,
        vpH: vpH,
        scale: _scale,
        offset: _offset,
      );
      final media = MediaQuery.of(context);
      final outW = (media.size.width * media.devicePixelRatio).round();
      final outH = (media.size.height * media.devicePixelRatio).round();
      final path = await WallpaperService.instance.cropAndSave(
        srcPath: widget.imagePath,
        cropX: rect.left,
        cropY: rect.top,
        cropW: rect.width,
        cropH: rect.height,
        outW: outW,
        outH: outH,
      );
      final ok = await WallpaperService.instance.setWallpaper(path);
      if (mounted) Navigator.of(context).pop(ok);
    } catch (_) {
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final screenRatio = media.size.width / media.size.height;

    return GlassBackground(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.cropWallpaper)),
        body: _decodeFailed
            ? _errorView(l10n)
            : _imgSize == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final maxH = constraints.maxHeight;
                  double vpW, vpH;
                  if (maxW / maxH > screenRatio) {
                    vpH = maxH;
                    vpW = vpH * screenRatio;
                  } else {
                    vpW = maxW;
                    vpH = vpW / screenRatio;
                  }
                  _ensureView(vpW, vpH);
                  final rect = CropMath.cropRect(
                    imgW: _imgSize!.width,
                    imgH: _imgSize!.height,
                    vpW: vpW,
                    vpH: vpH,
                    scale: _scale,
                    offset: _offset,
                  );
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Text(
                          l10n.cropHint,
                          style: AppTextStyles.englishBody.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: (d) => _onScaleUpdate(d, vpW, vpH),
                            child: ClipRect(
                              child: SizedBox(
                                width: vpW,
                                height: vpH,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned(
                                      left: _offset.dx,
                                      top: _offset.dy,
                                      width: _imgSize!.width * _scale,
                                      height: _imgSize!.height * _scale,
                                      child: Image.file(
                                        File(widget.imagePath),
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                    IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.55,
                                            ),
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                        child: Text(
                          '${rect.width.round()} × ${rect.height.round()} px',
                          style: AppTextStyles.englishBody.copyWith(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: Text(l10n.cancel),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _apply(vpW, vpH),
                                icon: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.wallpaper),
                                label: Text(l10n.setAsWallpaper),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _errorView(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(l10n.wallpaperSetFailed, style: AppTextStyles.englishBody),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}
