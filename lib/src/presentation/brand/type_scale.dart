import 'package:flutter/material.dart';

/// The type scale, declared rather than inherited.
///
/// Most of these sizes are Material's own, and that is deliberate: inventing
/// different numbers so the scale looks bespoke would be change without
/// improvement. What was missing was the **declaration** — three roles were
/// customised in `theme.dart` and the other nine were whatever Material
/// happened to provide, so nobody could say what `titleMedium` was for or
/// why `bodySmall` looked the way it did.
///
/// Every size here is a logical pixel at a text scale of 1.0. Flutter
/// multiplies them by the reader's chosen scale, so a phone at the largest
/// accessibility setting renders these at a little over three times the size
/// — which is what Day 13's sweep and Day 22's re-pass exist to check.
abstract final class TypeScale {
  /// The leader's name, and nothing else.
  ///
  /// Tight tracking and a tight line, because at this size Material's
  /// defaults leave a name looking like a headline in a newspaper.
  static const TextStyle display = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.05,
  );

  /// Screen-level headings — "No rota yet", "Nothing written yet".
  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// The name on a row: who leads a given week, who is next.
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Reading text set at a size somebody can sit with — the saying, a
  /// journal entry.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// The default. Explanations, descriptions, most sentences.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Supporting detail: a date under a name, a caption under a saying.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Small, spaced and quiet — "This week", "Coming up", the app bar title.
  ///
  /// The wide tracking is what makes it read as a label rather than as a
  /// short sentence. It labels the thing below it and must not compete
  /// with it.
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    height: 1.2,
  );

  /// Builds a Material text theme from the scale, in one colour scheme.
  ///
  /// Colour is applied here rather than in each style, so that a style is
  /// never carrying a colour from the wrong theme — the commonest way a
  /// dark mode ends up with one unreadable line in it.
  static TextTheme themed(ColorScheme colours) {
    final Color on = colours.onSurface;
    final Color muted = colours.onSurfaceVariant;

    return TextTheme(
      displayLarge: display.copyWith(color: on),
      displayMedium: display.copyWith(color: on),
      displaySmall: display.copyWith(color: on),
      headlineLarge: headline.copyWith(color: on),
      headlineMedium: headline.copyWith(color: on),
      headlineSmall: headline.copyWith(color: on),
      titleLarge: title.copyWith(fontSize: 18, color: on),
      titleMedium: title.copyWith(color: on),
      titleSmall: title.copyWith(fontSize: 14, color: on),
      bodyLarge: bodyLarge.copyWith(color: on),
      bodyMedium: body.copyWith(color: muted),
      bodySmall: caption.copyWith(color: muted),
      labelLarge: label.copyWith(color: muted),
      labelMedium: label.copyWith(fontSize: 12, color: muted),
      labelSmall: label.copyWith(fontSize: 11, color: muted),
    );
  }
}
