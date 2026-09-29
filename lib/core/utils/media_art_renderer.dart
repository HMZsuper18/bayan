import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Renders the artwork shown by the system media player (control centre,
/// lock screen, Android Auto) for a recitation.
///
/// The result is a PNG cached on disk per reciter + surah, served to
/// `audio_service` through a `file://` art URI. Rendering happens off-screen
/// with a `PictureRecorder`, so no widget tree is involved and this file stays
/// free of widget imports.
class MediaArtRenderer {
  MediaArtRenderer._();

  static const int artSize = 512;
  static const String _arabicFont = 'AmiriQuran';
  static const String _uiFont = 'Tajawal';
  static bool _fontsLoaded = false;

  /// Returns the cached PNG for [reciterId] + [surahId], rendering it on first
  /// use. Returns `null` whenever rendering fails, in which case the
  /// notification simply falls back to the status-bar icon.
  static Future<File?> render({
    required String reciterId,
    required int surahId,
    required String surahArabicName,
    required String surahEnglishName,
    required String reciterName,
  }) async {
    if (reciterId.isEmpty || surahId <= 0) return null;
    try {
      final file = File('${(await _cacheDir()).path}/${reciterId}_$surahId.png');
      if (await file.exists()) return file;

      await _ensureFonts();

      final bytes = await _drawPng(
        surahArabicName: surahArabicName,
        surahEnglishName: surahEnglishName,
        reciterName: reciterName,
      );
      if (bytes == null) return null;

      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/media_art');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Off-screen text is not loaded by a regular widget paint, so load the two
  /// families we draw with explicitly.
  static Future<void> _ensureFonts() async {
    if (_fontsLoaded) return;
    _fontsLoaded = true;
    await Future.wait([
      _loadFont(_arabicFont, 'assets/fonts/AmiriQuran-Regular.ttf'),
      _loadFont(_uiFont, 'assets/fonts/Tajawal-Regular.ttf'),
    ]);
  }

  static Future<void> _loadFont(String family, String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final loader = FontLoader(family);
      loader.addFont(Future<ByteData>.value(data));
      await loader.load();
    } catch (_) {
      // Fall back to the default font rather than failing the whole artwork.
    }
  }

  static Future<List<int>?> _drawPng({
    required String surahArabicName,
    required String surahEnglishName,
    required String reciterName,
  }) async {
    final size = ui.Size(artSize.toDouble(), artSize.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final bounds = ui.Offset.zero & size;

    canvas.drawRect(
      bounds,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          const [ui.Color(0xFF00674F), ui.Color(0xFF013B2D)],
        ),
    );

    // Soft decorative arcs.
    final decor = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const ui.Color(0x14FFFFFF);
    canvas.drawCircle(const ui.Offset(470, 60), 150, decor);
    canvas.drawCircle(const ui.Offset(40, 470), 170, decor);

    // Frame.
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(28, 28, artSize - 56, artSize - 56),
        const ui.Radius.circular(36),
      ),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const ui.Color(0x40FFFFFF),
    );

    if (surahArabicName.isNotEmpty) {
      _centered(
        canvas,
        surahArabicName,
        y: 170,
        style: TextStyle(
          fontFamily: _arabicFont,
          fontSize: 76,
          height: 1.4,
          color: const ui.Color(0xFFFFFFFF),
        ),
      );
    }

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH((artSize - 72) / 2, 268, 72, 3),
        const ui.Radius.circular(2),
      ),
      ui.Paint()..color = const ui.Color(0x66FFFFFF),
    );

    if (surahEnglishName.isNotEmpty) {
      _centered(
        canvas,
        surahEnglishName,
        y: 296,
        style: TextStyle(
          fontFamily: _uiFont,
          fontSize: 26,
          fontWeight: ui.FontWeight.w500,
          letterSpacing: 0.6,
          color: const ui.Color(0xF2FFFFFF),
        ),
      );
    }

    if (reciterName.isNotEmpty) {
      _centered(
        canvas,
        reciterName,
        y: 344,
        style: TextStyle(
          fontFamily: _uiFont,
          fontSize: 22,
          color: const ui.Color(0xB3FFFFFF),
        ),
      );
    }

    _centered(
      canvas,
      'بيان',
      y: 444,
      style: TextStyle(
        fontFamily: _arabicFont,
        fontSize: 30,
        color: const ui.Color(0x80FFFFFF),
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(artSize, artSize);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data?.buffer.asUint8List();
  }

  static void _centered(
    ui.Canvas canvas,
    String text, {
    required double y,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: artSize - 96.0);
    painter.paint(canvas, ui.Offset((artSize - painter.width) / 2, y));
  }
}
