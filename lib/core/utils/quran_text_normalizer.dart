import 'dart:collection';

class QuranTextNormalizer {
  static final _diacriticOrder = <int, int>{
    0x064B: 1, 0x064C: 1, 0x064D: 1, 0x064E: 1, 0x064F: 1,
    0x0650: 1, 0x0651: 0, 0x0652: 2, 0x0653: 3,
  };

  static final _nfcMap = <int, Map<int, int>>{
    0x0627: {0x0653: 0x0622, 0x0654: 0x0623, 0x0655: 0x0625},
    0x0648: {0x0654: 0x0624},
    0x064A: {0x0654: 0x0626},
  };

  /// Memoizes [preProcessForDisplay] results because normalize() is idempotent
  /// and the renderers call it on every build (e.g. all 286 verses of a surah
  /// on each rebuild). Bounded to avoid unbounded growth on dynamic text.
  ///
  /// Note: must only be called from the main isolate (it is today — the
  /// `compute()` in seed_data.dart only parses JSON), as this static mutable
  /// map is not isolate-safe.
  static const int _displayCacheLimit = 20000;
  static final Map<String, String> _displayCache = {};

  static String normalize(String text) {
    if (text.isEmpty) return text;
    text = _nfc(text);
    text = _reorderDiacritics(text);
    text = _fixOrphanedMarks(text);
    return text;
  }

  /// Returns true for combining marks (harakat, waqf signs, small-high marks,
  /// hamza/maad marks) plus the extended Quranic marks U+08D3-U+08FF.
  ///
  /// Note: U+06DE (rub el hizb ۞) and U+06E9 (place of sajdah) fall inside the
  /// 0x06D6-0x06ED range but are spacing ornaments, not combining marks; they
  /// are handled separately in [_fixOrphanedMarks] and preserved verbatim.
  static bool _isCombiningMark(int code) {
    return (code >= 0x0610 && code <= 0x061A) ||
        (code >= 0x064B && code <= 0x065F) ||
        (code >= 0x06D6 && code <= 0x06ED) ||
        (code >= 0x08D3 && code <= 0x08FF);
  }

  /// Positions combining marks that follow a space directly after the preceding
  /// letter (e.g. "ٱللَّهُ ۚ غَفُورًا" -> "ٱللَّهُۚ غَفُورًا") so the text
  /// shaper attaches them to a real base glyph instead of drawing a dotted
  /// circle (U+25CC) placeholder. This never deletes marks: spacing ornaments
  /// (U+06DE rub el hizb ۞, U+06E9 place of sajdah) are kept as-is and render
  /// standalone, and the only codepoints dropped are U+08D3-U+08FF, which the
  /// bundled font cannot render (none occur in the current data).
  static String _fixOrphanedMarks(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x08D3 && code <= 0x08FF) continue; // font can't render these
      if (code == 0x06DE || code == 0x06E9) {
        // Spacing ornaments render standalone — keep them untouched.
        buffer.writeCharCode(code);
        continue;
      }
      if (!_isCombiningMark(code)) {
        buffer.writeCharCode(code);
        continue;
      }
      if (buffer.isEmpty) continue; // mark at start of text: no base, drop it
      var s = buffer.toString();
      while (s.endsWith(' ')) {
        s = s.substring(0, s.length - 1);
      }
      if (s.isEmpty) continue; // only spaces before the mark: drop it
      buffer.clear();
      buffer.write(s);
      buffer.writeCharCode(code);
    }
    return buffer.toString().trimLeft();
  }

  static String _nfc(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (i + 1 < text.length && _nfcMap[code] != null) {
        final next = text.codeUnitAt(i + 1);
        final composed = _nfcMap[code]![next];
        if (composed != null) {
          buffer.writeCharCode(composed);
          i++;
          continue;
        }
      }
      buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  static String _reorderDiacritics(String text) {
    final buffer = StringBuffer();
    final diacriticQueue = Queue<_Diacritic>();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0xFE00 && code <= 0xFE0F) continue;
      if (_isDiacritic(code)) {
        diacriticQueue.add(_Diacritic(code, i));
        continue;
      }
      _flushDiacritics(buffer, diacriticQueue, i);
      buffer.writeCharCode(code);
    }
    _flushDiacritics(buffer, diacriticQueue, text.length);
    return buffer.toString();
  }

  static void _flushDiacritics(
      StringBuffer buffer, Queue<_Diacritic> queue, int position) {
    final sorted = queue.toList()
      ..sort((a, b) {
        final orderA = _diacriticOrder[a.code] ?? 9;
        final orderB = _diacriticOrder[b.code] ?? 9;
        final cmp = orderA.compareTo(orderB);
        return cmp != 0 ? cmp : a.position.compareTo(b.position);
      });
    for (final d in sorted) {
      buffer.writeCharCode(d.code);
    }
    queue.clear();
  }

  static String preProcessForDisplay(String text) {
    final cached = _displayCache[text];
    if (cached != null) return cached;
    if (_displayCache.length >= _displayCacheLimit) {
      _displayCache.remove(_displayCache.keys.first);
    }
    final result = normalize(text);
    _displayCache[text] = result;
    return result;
  }

  static bool _isDiacritic(int code) {
    return (code >= 0x064B && code <= 0x0653) ||
        (code >= 0x0655 && code <= 0x0658) ||
        code == 0x06E1 ||
        code == 0x06E2 ||
        code == 0x06E3 ||
        code == 0x06E4 ||
        code == 0x06E5 ||
        code == 0x06E6 ||
        code == 0x06E7 ||
        code == 0x06E8 ||
        code == 0x06EA ||
        code == 0x06EB ||
        code == 0x06EC ||
        code == 0x06ED;
  }

  static String toHex(String text) {
    return text.runes.map((r) => 'U+${r.toRadixString(16).padLeft(4, '0')}').join(' ');
  }
}

class _Diacritic {
  final int code;
  final int position;
  const _Diacritic(this.code, this.position);
}
