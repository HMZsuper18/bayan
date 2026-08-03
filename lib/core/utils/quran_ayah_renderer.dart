import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'quran_pua_substitution.dart';
import 'quran_render_config.dart';

class QuranAyahRenderer {
  QuranAyahRenderer._();

  static final Map<int, ui.Picture> _pictureCache = {};
  static final Map<int, ui.Paragraph> _paragraphCache = {};

  static int _cacheKey(String text, double fontSize, int color) {
    return Object.hash(text, fontSize, color);
  }

  static ui.Paragraph buildParagraph({
    required String text,
    required double fontSize,
    required Color color,
    double lineWidth = 800,
    double lineSpacing = 1.8,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        fontSize: fontSize,
        fontFamily: QuranRenderConfig.fontFamily,
        height: lineSpacing,
        textHeightBehavior: const ui.TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      ),
    );
    builder.pushStyle(
      ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: QuranRenderConfig.fontFamily,
        fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
        locale: const ui.Locale('ar'),
        fontFeatures: [
          const ui.FontFeature('mark', 1),
          const ui.FontFeature('mkmk', 1),
          const ui.FontFeature('rlig', 1),
          const ui.FontFeature('liga', 1),
          const ui.FontFeature('calt', 1),
          const ui.FontFeature('curs', 1),
          const ui.FontFeature('kern', 1),
          const ui.FontFeature('init', 1),
          const ui.FontFeature('medi', 1),
          const ui.FontFeature('fina', 1),
          const ui.FontFeature('isol', 1),
          const ui.FontFeature('dlig', 0),
        ],
      ),
    );
    builder.addText(text);
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: lineWidth));
    return paragraph;
  }

  static Future<ui.Picture> renderAyah({
    required String text,
    required double fontSize,
    required Color color,
    double lineWidth = 800,
    double lineSpacing = 1.8,
  }) async {
    final key = _cacheKey(text, fontSize, color.toARGB32());
    final cached = _pictureCache[key];
    if (cached != null) return cached;

    final substituted = QuranPuaSubstitution.substitute(text);
    final paragraph = buildParagraph(
      text: substituted,
      fontSize: fontSize,
      color: color,
      lineWidth: lineWidth,
      lineSpacing: lineSpacing,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawParagraph(paragraph, Offset.zero);
    final picture = recorder.endRecording();
    _pictureCache[key] = picture;
    return picture;
  }

  static ui.Paragraph getCachedParagraph({
    required String text,
    required double fontSize,
    required Color color,
    double lineWidth = 800,
  }) {
    final key = _cacheKey(text, fontSize, color.toARGB32());
    final cached = _paragraphCache[key];
    if (cached != null) return cached;

    final substituted = QuranPuaSubstitution.substitute(text);
    final paragraph = buildParagraph(
      text: substituted,
      fontSize: fontSize,
      color: color,
      lineWidth: lineWidth,
    );
    _paragraphCache[key] = paragraph;
    return paragraph;
  }

  static Widget ayahWidget({
    required String text,
    required double fontSize,
    required Color color,
    double lineWidth = 800,
  }) {
    return _AyahPaintWidget(
      text: text,
      fontSize: fontSize,
      color: color,
      lineWidth: lineWidth,
    );
  }

  static void clearCache() {
    for (final picture in _pictureCache.values) {
      picture.dispose();
    }
    _pictureCache.clear();
    _paragraphCache.clear();
  }

  static Widget ayahPictureWidget({
    required Future<ui.Picture> picture,
    required double width,
    required double height,
  }) {
    return _PictureWidget(
      picture: picture,
      width: width,
      height: height,
    );
  }
}

class _AyahPaintWidget extends LeafRenderObjectWidget {
  final String text;
  final double fontSize;
  final Color color;
  final double lineWidth;

  const _AyahPaintWidget({
    required this.text,
    required this.fontSize,
    required this.color,
    required this.lineWidth,
  });

  @override
  _AyahRenderObject createRenderObject(BuildContext context) {
    return _AyahRenderObject(
      text: text,
      fontSize: fontSize,
      color: color,
      lineWidth: lineWidth,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _AyahRenderObject renderObject) {
    renderObject
      ..text = text
      ..fontSize = fontSize
      ..color = color
      ..lineWidth = lineWidth;
  }
}

class _AyahRenderObject extends RenderBox {
  _AyahRenderObject({
    required String text,
    required double fontSize,
    required Color color,
    required double lineWidth,
  })  : _text = text,
        _fontSize = fontSize,
        _color = color,
        _lineWidth = lineWidth;

  String _text;
  double _fontSize;
  Color _color;
  double _lineWidth;

  set text(String v) {
    if (_text == v) return;
    _text = v;
    markNeedsLayout();
  }

  set fontSize(double v) {
    if (_fontSize == v) return;
    _fontSize = v;
    markNeedsLayout();
  }

  set color(Color v) {
    if (_color == v) return;
    _color = v;
    markNeedsPaint();
  }

  set lineWidth(double v) {
    if (_lineWidth == v) return;
    _lineWidth = v;
    markNeedsLayout();
  }

  ui.Paragraph? _paragraph;

  @override
  void performLayout() {
    final constraints = this.constraints;
    final width = math.min(_lineWidth, constraints.maxWidth);
    final substituted = QuranPuaSubstitution.substitute(_text);

    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        fontSize: _fontSize,
        fontFamily: QuranRenderConfig.fontFamily,
        height: 1.8,
        textHeightBehavior: const ui.TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
      ),
    );
    builder.pushStyle(
      ui.TextStyle(
        color: _color,
        fontSize: _fontSize,
        fontFamily: QuranRenderConfig.fontFamily,
        fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
        locale: const ui.Locale('ar'),
        fontFeatures: [
          const ui.FontFeature('mark', 1),
          const ui.FontFeature('mkmk', 1),
          const ui.FontFeature('rlig', 1),
          const ui.FontFeature('liga', 1),
          const ui.FontFeature('calt', 1),
          const ui.FontFeature('curs', 1),
          const ui.FontFeature('kern', 1),
          const ui.FontFeature('init', 1),
          const ui.FontFeature('medi', 1),
          const ui.FontFeature('fina', 1),
          const ui.FontFeature('isol', 1),
          const ui.FontFeature('dlig', 0),
        ],
      ),
    );
    builder.addText(substituted);
    _paragraph = builder.build();
    _paragraph!.layout(ui.ParagraphConstraints(width: width));
    size = Size(width, _paragraph!.height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_paragraph != null) {
      final canvas = context.canvas;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.drawParagraph(_paragraph!, Offset.zero);
      canvas.restore();
    }
  }
}

class _PictureWidget extends StatelessWidget {
  final Future<ui.Picture> picture;
  final double width;
  final double height;

  const _PictureWidget({
    required this.picture,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Picture>(
      future: picture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(width: width, height: height);
        }
        return CustomPaint(
          size: Size(width, height),
          painter: _PicturePainter(picture: snapshot.data!),
        );
      },
    );
  }
}

class _PicturePainter extends CustomPainter {
  final ui.Picture picture;

  _PicturePainter({required this.picture});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(_PicturePainter oldDelegate) {
    return picture != oldDelegate.picture;
  }
}
