import 'package:flutter/material.dart';

/// The type scale, declared rather than inherited.
abstract final class TypeScale {
  /// The leader's name, and nothing else.
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
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    height: 1.2,
  );

  /// Builds a Material text theme from the scale, in one colour scheme.
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
