import 'dart:io';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PageNumberOcrResult {
  final String cleanedText;
  final String rawText;
  final String? debugCropPath;

  PageNumberOcrResult({
    required this.cleanedText,
    required this.rawText,
    this.debugCropPath,
  });
}

class PageNumberOcrService {
  static const _digitWhitelist = '٠١٢٣٤٥٦٧٨٩';

  Future<PageNumberOcrResult> readPageNumber(
    img.Image pageImage, {
    required int x,
    required int y,
    required int width,
    required int height,
    String? debugDir,
  }) async {
    final cropped = img.copyCrop(pageImage, x: x, y: y, width: width, height: height);
    final preprocessed = _preprocess(cropped);

    String? cropPath;
    if (debugDir != null) {
      cropPath = '$debugDir/page_number_crop.png';
      await File(cropPath).writeAsBytes(img.encodePng(preprocessed));
    }

    final tempPath = await _writeTemp(preprocessed);
    try {
      final raw = await FlutterTesseractOcr.extractText(
        tempPath,
        language: 'ara',
        args: {
          'psm': '7',
          'tessedit_char_whitelist': _digitWhitelist,
        },
      );
      return PageNumberOcrResult(
        cleanedText: _clean(raw),
        rawText: raw,
        debugCropPath: cropPath,
      );
    } finally {
      final f = File(tempPath);
      if (await f.exists()) await f.delete();
    }
  }

  img.Image _preprocess(img.Image src) {
    final gray = img.grayscale(src);
    final t = _otsuThreshold(gray);
    final scaled = img.copyResize(gray, width: (src.width * 3).round());
    final binary = _binarize(scaled, threshold: t);
    return _dilate(binary);
  }

  static int _otsuThreshold(img.Image gray) {
    final histogram = List<int>.filled(256, 0);
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        histogram[gray.getPixel(x, y).r as int]++;
      }
    }
    final total = gray.width * gray.height;
    var sum = 0.0;
    for (var i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }
    var sumB = 0.0;
    var wB = 0.0;
    var maxVariance = 0.0;
    var threshold = 0;
    for (var i = 0; i < 256; i++) {
      wB += histogram[i];
      if (wB == 0) continue;
      final wF = total - wB;
      if (wF == 0) break;
      sumB += i * histogram[i];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;
      final variance = wB * wF * (mB - mF) * (mB - mF);
      if (variance > maxVariance) {
        maxVariance = variance;
        threshold = i;
      }
    }
    return threshold;
  }

  img.Image _binarize(img.Image gray, {required int threshold}) {
    final out = img.Image.from(gray);
    for (var yy = 0; yy < out.height; yy++) {
      for (var xx = 0; xx < out.width; xx++) {
        final lum = out.getPixel(xx, yy).r;
        out.setPixelRgb(xx, yy, lum < threshold ? 0 : 255, lum < threshold ? 0 : 255, lum < threshold ? 0 : 255);
      }
    }
    return out;
  }

  img.Image _dilate(img.Image src) {
    final out = img.Image.from(src);
    for (var yy = 1; yy < src.height - 1; yy++) {
      for (var xx = 1; xx < src.width - 1; xx++) {
        if (src.getPixel(xx, yy).r > 128) {
          bool anyBlack = false;
          for (var ny = yy - 1; ny <= yy + 1 && !anyBlack; ny++) {
            for (var nx = xx - 1; nx <= xx + 1 && !anyBlack; nx++) {
              if (src.getPixel(nx, ny).r < 128) anyBlack = true;
            }
          }
          if (anyBlack) out.setPixelRgb(xx, yy, 0, 0, 0);
        }
      }
    }
    return out;
  }

  Future<String> _writeTemp(img.Image image) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/page_number_${DateTime.now().microsecondsSinceEpoch}.png';
    await File(path).writeAsBytes(img.encodePng(image));
    return path;
  }

  String _clean(String raw) {
    final buffer = StringBuffer();
    for (final char in raw.runes) {
      final c = String.fromCharCode(char);
      if (_digitWhitelist.contains(c)) buffer.write(c);
    }
    return buffer.toString();
  }

  static int? toWesternInt(String arabicIndicNumber) {
    const map = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };
    final western = arabicIndicNumber.split('').map((c) => map[c] ?? c).join();
    return int.tryParse(western);
  }
}
