import 'package:flutter/material.dart';

import 'palette.dart';

/// The app's theme.
///
/// Shaped rather than seeded. The type scale is tightened where it matters —
/// a name set large needs less letter spacing than Material's default, and a
/// label above it needs more — because the whole screen is one name and the
/// words around it.
abstract final class AppTheme {
  static ThemeData light() => _build(Palette.light);

  static ThemeData dark() => _build(Palette.dark);

  static ThemeData _build(ColorScheme colours) {
    final ThemeData base = ThemeData(colorScheme: colours, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: colours.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colours.surface,
        foregroundColor: colours.onSurfaceVariant,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: base.textTheme.labelLarge?.copyWith(
          color: colours.onSurfaceVariant,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: colours.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dividerTheme: DividerThemeData(
        color: colours.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: base.textTheme.titleMedium,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textTheme: base.textTheme.copyWith(
        // The leader's name. Large, tight, and the only thing set in the
        // surface's full-strength colour.
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          height: 1.05,
          color: colours.onSurface,
        ),
        // "This week" — small, spaced, quiet. It labels the name; it does not
        // compete with it.
        labelLarge: base.textTheme.labelLarge?.copyWith(
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
          color: colours.onSurfaceVariant,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: colours.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    );
  }
}
