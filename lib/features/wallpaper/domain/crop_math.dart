import 'dart:ui';

/// Pure geometry for the wallpaper crop screen: how to cover a viewport with
/// an image, how to clamp panning, and which source rectangle is visible.
///
/// Kept free of Flutter widgets so it can be unit tested directly.
class CropMath {
  const CropMath._();

  /// Scale (image px per logical px) so an [imgW]×[imgH] image fully covers a
  /// [vpW]×[vpH] viewport — the same thing Android's wallpaper cropper does.
  static double coverScale({
    required double imgW,
    required double imgH,
    required double vpW,
    required double vpH,
  }) {
    if (imgW <= 0 || imgH <= 0 || vpW <= 0 || vpH <= 0) return 1;
    final sW = vpW / imgW;
    final sH = vpH / imgH;
    return sW > sH ? sW : sH;
  }

  /// Clamps a pan [offset] (image top-left relative to viewport top-left) so
  /// the scaled image ([dispW]×[dispH]) always covers the viewport.
  static Offset clampOffset({
    required Offset offset,
    required double dispW,
    required double dispH,
    required double vpW,
    required double vpH,
  }) {
    final minX = vpW - dispW; // ≤ 0 when covering
    final minY = vpH - dispH;
    return Offset(
      offset.dx < minX ? minX : (offset.dx > 0 ? 0 : offset.dx),
      offset.dy < minY ? minY : (offset.dy > 0 ? 0 : offset.dy),
    );
  }

  /// Source rectangle (image pixels) currently visible in the viewport.
  /// [scale] is image px per logical px, [offset] the pan from [clampOffset].
  static Rect cropRect({
    required double imgW,
    required double imgH,
    required double vpW,
    required double vpH,
    required double scale,
    required Offset offset,
  }) {
    if (scale <= 0) scale = 1;
    final sx = (-offset.dx / scale).clamp(0.0, imgW);
    final sy = (-offset.dy / scale).clamp(0.0, imgH);
    final sw = (vpW / scale).clamp(0.0, imgW - sx);
    final sh = (vpH / scale).clamp(0.0, imgH - sy);
    return Rect.fromLTWH(sx, sy, sw, sh);
  }
}
