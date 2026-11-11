import 'package:flutter/material.dart';

/// The app's colours, taken from the family's totem.
abstract final class Palette {
  /// Honey. The accent, at full strength — on dark grounds only.
  static const Color honey = Color(0xFFE8A317);

  /// Honey deepened until it can be seen on wax: 4.20:1, which clears the
  /// 3:1 bar for lines and icons and the 3:1 bar for large text.
  static const Color amber = Color(0xFFA86B0A);

  /// Deeper still, for accent **words** on a pale ground: 5.86:1.
  static const Color amberDeep = Color(0xFF8A5606);

  /// The dark of a bee, and of the inside of a hive. Brown rather than
  /// black, so honey sits warm against it instead of glaring.
  static const Color ink = Color(0xFF1A1410);

  /// One step up from [ink], for a card on a dark ground.
  static const Color inkRaised = Color(0xFF241C15);

  /// Wax. The pale ground: warm, so the app never feels clinical.
  static const Color wax = Color(0xFFFFF9ED);

  /// Wax a shade deeper, for a card on a pale ground.
  static const Color waxRaised = Color(0xFFF7EDD8);

  /// Muted text on wax: 7.48:1.
  static const Color waxMuted = Color(0xFF5C5040);

  /// Muted text on ink: 7.80:1.
  static const Color inkMuted = Color(0xFFB5A892);

  /// A wash of honey, for a chip or a badge on wax.
  static const Color honeyWash = Color(0xFFF7EDD8);

  /// The same idea on ink.
  static const Color honeyWashNight = Color(0xFF2E2419);

  static const Color combLine = Color(0xFFE6D7B8);

  /// The comb line on a dark ground.
  static const Color combLineNight = Color(0xFF423524);

  static const ColorScheme light = ColorScheme.light(
    primary: ink,
    onPrimary: wax,
    secondary: amber,
    onSecondary: wax,
    surface: wax,
    onSurface: ink,
    surfaceContainerHighest: waxRaised,
    onSurfaceVariant: waxMuted,
    outlineVariant: combLine,
    secondaryContainer: honeyWash,
    onSecondaryContainer: amberDeep,
  );

  static const ColorScheme dark = ColorScheme.dark(
    primary: honey,
    onPrimary: ink,
    secondary: honey,
    onSecondary: ink,
    surface: ink,
    onSurface: wax,
    surfaceContainerHighest: inkRaised,
    onSurfaceVariant: inkMuted,
    outlineVariant: combLineNight,
    secondaryContainer: honeyWashNight,
    onSecondaryContainer: honey,
  );
}
