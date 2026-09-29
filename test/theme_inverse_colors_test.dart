import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan/core/theme/app_theme.dart';

double _luminance(Color color) {
  double channel(double v) => v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final light = math.max(la, lb);
  final dark = math.min(la, lb);
  return (light + 0.05) / (dark + 0.05);
}

const String _message = 'Downloading wallpaper...';

Future<TextStyle> _snackBarTextStyle(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
  final messenger = tester.state<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  );
  messenger.showSnackBar(const SnackBar(content: Text(_message)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(find.text(_message), findsOneWidget);
  final rich = tester.widget<RichText>(
    find.descendant(of: find.text(_message), matching: find.byType(RichText)),
  );
  return rich.text.style!;
}

void main() {
  group('inverse color scheme tokens (SnackBar / banner surfaces)', () {
    test('light theme inverse text is opaque and legible', () {
      final scheme = AppTheme.light().colorScheme;
      expect(scheme.onInverseSurface.a, 1.0);
      expect(
        _contrast(scheme.onInverseSurface, scheme.inverseSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark theme inverse text is opaque and legible', () {
      final scheme = AppTheme.dark().colorScheme;
      expect(scheme.onInverseSurface.a, 1.0);
      expect(
        _contrast(scheme.onInverseSurface, scheme.inverseSurface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  testWidgets('SnackBar message paints opaque text in light theme', (tester) async {
    final theme = AppTheme.light();
    final color = (await _snackBarTextStyle(tester, theme)).color!;
    expect(color.a, 1.0);
    expect(
      _contrast(color, theme.colorScheme.inverseSurface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('SnackBar message paints opaque text in dark theme', (tester) async {
    final theme = AppTheme.dark();
    final color = (await _snackBarTextStyle(tester, theme)).color!;
    expect(color.a, 1.0);
    expect(
      _contrast(color, theme.colorScheme.inverseSurface),
      greaterThanOrEqualTo(4.5),
    );
  });
}
