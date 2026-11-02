import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';
import 'type_scale.dart';

/// The app's theme, assembled from tokens.
///
/// Nothing here invents a number. Sizes come from [Space] and [Radii],
/// text from [TypeScale], colour from [Palette] — so a change to any of
/// them reaches every screen, and a screen that wants something the tokens
/// do not offer has to justify itself rather than quietly adding a
/// fourteenth spacing value.
abstract final class AppTheme {
  static ThemeData light() => _build(Palette.light);

  static ThemeData dark() => _build(Palette.dark);

  static ThemeData _build(ColorScheme colours) {
    final TextTheme text = TypeScale.themed(colours);

    return ThemeData(
      colorScheme: colours,
      useMaterial3: true,
      textTheme: text,
      scaffoldBackgroundColor: colours.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: colours.surface,
        foregroundColor: colours.onSurfaceVariant,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.labelLarge,
      ),

      cardTheme: CardThemeData(
        color: colours.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
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
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          textStyle: TypeScale.title,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // Day 22 measures touch targets. Setting the floor here means
          // every TextButton in the app clears it without each one
          // remembering to.
          minimumSize: const Size(Touch.minimum, Touch.minimum),
          textStyle: TypeScale.title,
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
        minVerticalPadding: Space.md,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),

      // Filled rather than outlined. An outline is a box drawn around
      // nothing; a fill says "type here" before anybody reads the label,
      // and it is what both platforms' own apps have settled on.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colours.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colours.outlineVariant),
        ),
        // The focused field is the only place the accent appears at full
        // strength on a pale ground, and it is two pixels rather than one
        // so that "which field am I in" is answerable without looking for
        // the caret.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colours.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colours.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colours.error, width: 2),
        ),
        labelStyle: TypeScale.body.copyWith(color: colours.onSurfaceVariant),
        floatingLabelStyle: TypeScale.caption.copyWith(
          color: colours.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TypeScale.body.copyWith(
          color: colours.onSurfaceVariant.withValues(alpha: 0.75),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
            ),
          ),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? colours.onPrimary
              : colours.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? colours.primary
              : colours.surfaceContainerHighest,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colours.primary,
        contentTextStyle: TypeScale.body.copyWith(color: colours.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
    );
  }
}
