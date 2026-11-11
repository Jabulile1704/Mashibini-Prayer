import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/presentation/brand/palette.dart';
import 'package:mashibini_prayer/src/presentation/brand/theme.dart';

/// N5 asks that the app is readable. Text scaling is only half of that; the
/// other half is contrast, and nothing in this project measured it until
/// Day 17.
void main() {
  /// Relative luminance, per WCAG 2.1.
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double ratio(Color a, Color b) {
    final double la = luminance(a);
    final double lb = luminance(b);
    final double hi = math.max(la, lb);
    final double lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// What [foreground] actually looks like once its alpha is applied over
  /// [background].
  Color composite(Color foreground, Color background) {
    final double a = foreground.a;
    return Color.fromARGB(
      255,
      ((foreground.r * a + background.r * (1 - a)) * 255).round(),
      ((foreground.g * a + background.g * (1 - a)) * 255).round(),
      ((foreground.b * a + background.b * (1 - a)) * 255).round(),
    );
  }

  void expectContrast(
    String what,
    Color foreground,
    Color background, {
    required double atLeast,
  }) {
    final double measured = ratio(
      composite(foreground, background),
      background,
    );
    expect(
      measured,
      greaterThanOrEqualTo(atLeast),
      reason: '$what is ${measured.toStringAsFixed(2)}:1, needs $atLeast:1',
    );
  }

  group('the measurement itself', () {
    test('black on white is 21:1 and white on white is 1:1', () {
      expect(
        ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        ratio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
        closeTo(1, 0.01),
      );
    });

    test('a faded colour measures as what it looks like', () {
      final double faded = ratio(
        composite(const Color(0x80000000), const Color(0xFFFFFFFF)),
        const Color(0xFFFFFFFF),
      );
      expect(faded, closeTo(4.00, 0.02));
    });
  });

  for (final (String name, ColorScheme c) in <(String, ColorScheme)>[
    ('light', Palette.light),
    ('dark', Palette.dark),
  ]) {
    group('$name theme', () {
      test('body text is readable on every surface it sits on', () {
        expectContrast(
          '$name onSurface on surface',
          c.onSurface,
          c.surface,
          atLeast: 4.5,
        );
        expectContrast(
          '$name onSurface on card',
          c.onSurface,
          c.surfaceContainerHighest,
          atLeast: 4.5,
        );
      });

      test('muted text is readable, which is where this usually fails', () {
        expectContrast(
          '$name onSurfaceVariant on surface',
          c.onSurfaceVariant,
          c.surface,
          atLeast: 4.5,
        );
        expectContrast(
          '$name onSurfaceVariant on card',
          c.onSurfaceVariant,
          c.surfaceContainerHighest,
          atLeast: 4.5,
        );
      });

      test('text on filled buttons is readable', () {
        expectContrast(
          '$name onPrimary on primary',
          c.onPrimary,
          c.primary,
          atLeast: 4.5,
        );
      });

      test('the accent clears the bar for graphics', () {
        expectContrast(
          '$name secondary on surface',
          c.secondary,
          c.surface,
          atLeast: 3,
        );
        expectContrast(
          '$name secondary on card',
          c.secondary,
          c.surfaceContainerHighest,
          atLeast: 3,
        );
      });

      test('the accent can carry text, through its container', () {
        expectContrast(
          '$name onSecondaryContainer on secondaryContainer',
          c.onSecondaryContainer,
          c.secondaryContainer,
          atLeast: 4.5,
        );
      });

      test('a faded body colour still clears the bar', () {
        for (final double alpha in <double>[0.82, 0.70]) {
          expectContrast(
            '\$name saying text at \${(alpha * 100).round()}%',
            c.onSurface.withValues(alpha: alpha),
            c.surfaceContainerHighest,
            atLeast: 4.5,
          );
        }
      });

      test('the version line is readable, which it was not', () {
        expectContrast(
          '$name version line',
          c.onSurfaceVariant,
          c.surface,
          atLeast: 4.5,
        );
      });

      test('the disabled treatment is readable, or it is not used', () {
        final ThemeData theme = name == 'light'
            ? AppTheme.light()
            : AppTheme.dark();
        expectContrast(
          '$name disabledColor on surface',
          theme.disabledColor,
          c.surface,
          atLeast: 3,
        );
        expectContrast(
          '$name disabledColor on card',
          theme.disabledColor,
          c.surfaceContainerHighest,
          atLeast: 3,
        );
      });

      test('dividers are visible', () {
        expectContrast(
          '$name outlineVariant on surface',
          c.outlineVariant,
          c.surface,
          atLeast: 1.3,
        );
      });
    });
  }
}
