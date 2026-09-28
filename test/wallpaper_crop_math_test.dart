import 'package:bayan/features/wallpaper/domain/crop_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CropMath.coverScale', () {
    test('portrait viewport vs landscape image scales to cover height', () {
      // 1080x720 photo on a 360x800 screen: 800/720 wins.
      final s = CropMath.coverScale(imgW: 1080, imgH: 720, vpW: 360, vpH: 800);
      expect(s, closeTo(800 / 720, 1e-9));
      expect(1080 * s, greaterThanOrEqualTo(360));
      expect(720 * s, greaterThanOrEqualTo(800));
    });

    test('portrait image on portrait viewport scales to cover width', () {
      final s = CropMath.coverScale(imgW: 1080, imgH: 1920, vpW: 360, vpH: 800);
      expect(
        s,
        closeTo(360 / 1080 < 800 / 1920 ? 800 / 1920 : 360 / 1080, 1e-9),
      );
      expect(1080 * s, greaterThanOrEqualTo(360 - 1e-9));
      expect(1920 * s, greaterThanOrEqualTo(800 - 1e-9));
    });

    test('degenerate inputs return 1', () {
      expect(CropMath.coverScale(imgW: 0, imgH: 720, vpW: 360, vpH: 800), 1);
    });
  });

  group('CropMath.clampOffset', () {
    test('keeps the scaled image covering the viewport', () {
      final o = CropMath.clampOffset(
        offset: const Offset(50, -900),
        dispW: 1200,
        dispH: 800,
        vpW: 360,
        vpH: 800,
      );
      expect(o.dx, 0); // pushed back from positive
      expect(o.dy, 0); // vpH - dispH == 0
    });

    test('limits panning to the image edges', () {
      final o = CropMath.clampOffset(
        offset: const Offset(-9999, -9999),
        dispW: 1200,
        dispH: 1000,
        vpW: 360,
        vpH: 800,
      );
      expect(o.dx, 360 - 1200); // -840
      expect(o.dy, 800 - 1000); // -200
    });
  });

  group('CropMath.cropRect', () {
    test('centered cover crop matches viewport aspect exactly', () {
      const imgW = 1080.0, imgH = 720.0, vpW = 360.0, vpH = 800.0;
      final s = CropMath.coverScale(imgW: imgW, imgH: imgH, vpW: vpW, vpH: vpH);
      final dispW = imgW * s, dispH = imgH * s;
      final offset = CropMath.clampOffset(
        offset: Offset((vpW - dispW) / 2, (vpH - dispH) / 2),
        dispW: dispW,
        dispH: dispH,
        vpW: vpW,
        vpH: vpH,
      );
      final r = CropMath.cropRect(
        imgW: imgW,
        imgH: imgH,
        vpW: vpW,
        vpH: vpH,
        scale: s,
        offset: offset,
      );
      // Same aspect as the viewport/screen — Android will not crop further.
      expect(r.width / r.height, closeTo(vpW / vpH, 1e-9));
      // Fully inside the source image.
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(imgW));
      expect(r.bottom, lessThanOrEqualTo(imgH));
      // Center slice of the landscape photo.
      expect(r.left, closeTo((imgW - r.width) / 2, 1e-6));
      expect(r.top, closeTo(0, 1e-6));
    });

    test('never returns a rect outside the image at any pan position', () {
      const imgW = 1080.0, imgH = 720.0, vpW = 360.0, vpH = 800.0;
      final s = CropMath.coverScale(imgW: imgW, imgH: imgH, vpW: vpW, vpH: vpH);
      for (final raw in const [
        Offset(0, 0),
        Offset(-10000, -10000),
        Offset(9999, 9999),
      ]) {
        final o = CropMath.clampOffset(
          offset: raw,
          dispW: imgW * s,
          dispH: imgH * s,
          vpW: vpW,
          vpH: vpH,
        );
        final r = CropMath.cropRect(
          imgW: imgW,
          imgH: imgH,
          vpW: vpW,
          vpH: vpH,
          scale: s,
          offset: o,
        );
        expect(r.left, inInclusiveRange(0, imgW));
        expect(r.top, inInclusiveRange(0, imgH));
        expect(r.width / r.height, closeTo(vpW / vpH, 1e-6));
      }
    });
  });
}
