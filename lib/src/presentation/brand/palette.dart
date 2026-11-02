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

  /// A deeper ember, for when the accent has to carry text.
  ///
  /// [ember] itself is 3.46:1 on parchment — fine for an icon or an arc of
  /// the mark, where the bar is 3:1, and **not** fine for a word. Rather
  /// than darkening the brand colour to solve a problem the app does not yet
  /// have, there are two: one for graphics, one for text.
  static const Color emberDeep = Color(0xFF8F4A20);

  /// A pale wash of the accent, for a chip or a badge.
  static const Color emberWash = Color(0xFFF4EAE0);

  /// The same wash against a dark surface.
  static const Color emberWashNight = Color(0xFF382F30);

  /// The accent lightened for dark surfaces, where ember is too heavy.
  static const Color emberLight = Color(0xFFE9B78F);

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
    secondaryContainer: emberWash,
    onSecondaryContainer: emberDeep,
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
    secondaryContainer: emberWashNight,
    onSecondaryContainer: emberLight,
  );
}
