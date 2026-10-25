import 'package:flutter/material.dart';

/// The app's colours, chosen rather than generated.
///
/// `ColorScheme.fromSeed` is a good default, and it is a default: every app
/// that uses it looks like every other app that uses it. These are picked for
/// one screen a family looks at for about four seconds a week.
///
/// The intent is quiet. A prayer rota should not shout, and the one thing on
/// screen that earns emphasis is a person's name — so the palette stays
/// subdued and lets the name carry the weight.
abstract final class Palette {
  /// Deep indigo. Dark enough to read white on, soft enough not to be navy.
  static const Color ink = Color(0xFF1F2A44);

  /// The accent, used for exactly one thing: the current turn.
  ///
  /// Warm against the cool ink, so the eye lands on it without any other part
  /// of the screen needing to be brighter.
  static const Color ember = Color(0xFFC2703D);

  static const Color parchment = Color(0xFFFAF7F2);
  static const Color parchmentDim = Color(0xFFF1ECE4);
  static const Color slate = Color(0xFF5A6478);

  static const Color nightInk = Color(0xFF11161F);
  static const Color nightCard = Color(0xFF1A212D);
  static const Color nightText = Color(0xFFECE7DF);
  static const Color nightMuted = Color(0xFF99A2B1);

  static const ColorScheme light = ColorScheme.light(
    primary: ink,
    onPrimary: parchment,
    secondary: ember,
    onSecondary: parchment,
    surface: parchment,
    onSurface: ink,
    surfaceContainerHighest: parchmentDim,
    onSurfaceVariant: slate,
    outlineVariant: Color(0xFFDFD8CC),
  );

  static const ColorScheme dark = ColorScheme.dark(
    primary: parchment,
    onPrimary: ink,
    secondary: ember,
    onSecondary: nightInk,
    surface: nightInk,
    onSurface: nightText,
    surfaceContainerHighest: nightCard,
    onSurfaceVariant: nightMuted,
    outlineVariant: Color(0xFF2C3545),
  );
}
