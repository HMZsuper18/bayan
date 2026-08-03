import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'quran_render_config.dart';

class QuranPuaSubstitution {
  QuranPuaSubstitution._();

  static Map<String, int> _puaMap = {};

  static Map<String, int> get puaMap => Map.unmodifiable(_puaMap);

  static final Set<int> _supportedPua = {};

  static void initialize() {
    _puaMap = Map.from(_defaultMappings);
  }

  static String substitute(String text) {
    if (_puaMap.isEmpty) return text;
    final buffer = StringBuffer();
    int i = 0;
    while (i < text.length) {
      bool matched = false;
      for (final entry in _puaMap.entries) {
        final sequence = entry.key;
        if (text.startsWith(sequence, i)) {
          final pua = entry.value;
          if (_supportedPua.isEmpty || _supportedPua.contains(pua)) {
            buffer.writeCharCode(pua);
            i += sequence.length;
            matched = true;
            break;
          }
        }
      }
      if (!matched) {
        buffer.write(text[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  static Future<void> probeFontSupport() async {
    _supportedPua.clear();
    final allPua = _puaMap.values.toSet();
    for (final cp in allPua) {
      final supported = await _codepointSupported(cp);
      if (supported) {
        _supportedPua.add(cp);
      }
    }
  }

  static Future<bool> _codepointSupported(int codepoint) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textDirection: TextDirection.rtl,
        fontFamily: QuranRenderConfig.fontFamily,
        fontSize: 20,
      ),
    );
    builder.pushStyle(
      ui.TextStyle(
        fontFamily: QuranRenderConfig.fontFamily,
        fontFamilyFallback: QuranRenderConfig.fontFamilyFallback,
        fontSize: 20,
      ),
    );
    builder.addText(String.fromCharCode(codepoint));
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: 100));
    canvas.drawParagraph(paragraph, Offset.zero);
    final picture = recorder.endRecording();

    final image = await picture.toImage(100, 100);
    final byteData = await image.toByteData();
    if (byteData == null) return false;

    final pixels = byteData.buffer.asUint32List();
    for (final pixel in pixels) {
      if (pixel != 0) return true;
    }
    return false;
  }

  static void addMapping(String sequence, int puaCodepoint) {
    _puaMap[sequence] = puaCodepoint;
  }

  static final Map<String, int> _defaultMappings = {
    '\u{0623}\u{064F}\u{0648}\u{0644}\u{0670}\u{0653}\u{0626}\u{0650}\u{0643}': 0xFC00
  };

  static final Map<int, int> knownBaseSubstitutions = {
    0x0622: 0x0627,
    0x0623: 0x0627,
    0x0624: 0x0648,
    0x0625: 0x0627,
    0x0626: 0x064A,
  };

  static String decomposeToBase(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      final base = knownBaseSubstitutions[code];
      if (base != null) {
        buffer.writeCharCode(base);
        if (code == 0x0622) {
          buffer.writeCharCode(0x0653);
        } else if (code == 0x0623) {
          buffer.writeCharCode(0x0654);
        } else if (code == 0x0624) {
          buffer.writeCharCode(0x0654);
        } else if (code == 0x0625) {
          buffer.writeCharCode(0x0655);
        } else if (code == 0x0626) {
          buffer.writeCharCode(0x0654);
        }
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }
}
