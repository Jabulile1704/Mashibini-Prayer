import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/presentation/brand/palette.dart';

/// N5 asks that the app is readable. Text scaling is only half of that; the
/// other half is contrast, and nothing in this project measured it until
/// Day 17.
///
/// Day 13's sweep catches a layout that clips. It cannot catch grey text on
/// a grey card, which is why the version line added on Day 14 sat at **3.00**
/// against a 4.5 requirement for eight days without anything objecting.
///
/// These are WCAG 2.1 ratios: **4.5:1** for body text, **3:1** for large text
/// (roughly 24px, or 19px bold) and for meaningful non-text graphics.
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
  ///
  /// This is the part that matters. Every failure found on Day 17 was a
  /// colour that passes at full strength and fails once faded.
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

  // The checker is checked first. A contrast test that is itself wrong is
  // worse than no contrast test, because it is believed — and the first
  // version of this measurement, written as a throwaway script, read the
  // alpha byte as red and reported black-on-white as 3.7:1.
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
      // Half-strength black on white composites to #808080, which is about
      // 4:1 against white — not black's 21:1. That gap is the whole reason
      // this helper exists.
      //
      // The figure was wrong on the first two attempts: I guessed 5–6, then
      // 3.95 from memory of the usual mid-grey figure. It is 4.00, because
      // 0x80 is 128/255 — a shade above half, not half.
      //
      // Pinned tightly rather than loosened to fit. A measurement tool that
      // is allowed to be approximately right is a tool nobody can use to
      // contradict themselves.
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
        // The accent is only ever an icon or an arc of the mark — never
        // text. Non-text content needs 3:1, and this asserts the lower bar
        // deliberately rather than by accident. If the accent is ever used
        // behind text, this is the test that should change.
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
        // `secondary` on its own is for graphics. When Day 21 wants an
        // accent-coloured chip with a word in it, this is the pair that is
        // safe — and the gallery shows this one rather than the unsafe one,
        // so nobody reaches for the wrong slot.
        expectContrast(
          '$name onSecondaryContainer on secondaryContainer',
          c.onSecondaryContainer,
          c.secondaryContainer,
          atLeast: 4.5,
        );
      });

      test('a faded body colour still clears the bar', () {
        // The verse is set at 82% of onSurface.
        expectContrast(
          '$name verse text',
          c.onSurface.withValues(alpha: 0.82),
          c.surfaceContainerHighest,
          atLeast: 4.5,
        );
      });

      test('the version line is readable, which it was not', () {
        // Added on Day 14 as `onSurfaceVariant` at 70%, which measured
        // **3.00:1** in light and 4.07:1 in dark. It sat there for eight
        // days: Day 13's sweep checks that text fits, not that it can be
        // read.
        expectContrast(
          '$name version line',
          c.onSurfaceVariant,
          c.surface,
          atLeast: 4.5,
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
