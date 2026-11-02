import 'package:flutter/widgets.dart';

/// The spacing scale.
///
/// Before this there were **thirteen** distinct `SizedBox` heights across the
/// app — 2, 4, 8, 10, 12, 14, 16, 20, 24, 28, 32, 36 and 44. Most sat on a
/// 4pt grid, so the problem was never the grid: it was that every gap was a
/// fresh decision, and two gaps meant to look the same often did not.
///
/// Seven steps. Anything that does not fit one of them is a layout that has
/// not been thought about yet, which is useful information.
abstract final class Space {
  /// 4 — between a label and the thing it labels.
  static const double xs = 4;

  /// 8 — between tightly related lines.
  static const double sm = 8;

  /// 12 — inside a row or a list item.
  static const double md = 12;

  /// 16 — the default gap, and the screen gutter on narrow phones.
  static const double lg = 16;

  /// 24 — between groups that belong to the same section.
  static const double xl = 24;

  /// 32 — between sections.
  static const double xxl = 32;

  /// 48 — around something meant to stand alone.
  static const double xxxl = 48;

  /// The horizontal gutter every screen uses.
  static const EdgeInsets gutter = EdgeInsets.symmetric(horizontal: lg);

  /// Padding for a screen that is one column of content.
  static const EdgeInsets screen = EdgeInsets.fromLTRB(lg, lg, lg, xxl);
}

/// Corner radii.
///
/// Was 14, 16, 18 and 28 — four radii for five components, with no rule
/// saying which to use. Three, each tied to a size of thing.
abstract final class Radii {
  /// 12 — inputs and small controls.
  static const double sm = 12;

  /// 16 — buttons and list tiles.
  static const double md = 16;

  /// 28 — cards, and anything that reads as a surface rather than a control.
  static const double lg = 28;
}

/// How long things take.
///
/// Two durations. A third would be a decision nobody can make consistently.
abstract final class Motion {
  /// 150ms — a control responding to a touch.
  static const Duration quick = Duration(milliseconds: 150);

  /// 300ms — something arriving or leaving.
  static const Duration settle = Duration(milliseconds: 300);
}

/// The smallest a touch target may be.
///
/// 48 is the figure both Material and Apple's guidance land near, and it is
/// the one Day 22's accessibility pass will measure against.
abstract final class Touch {
  static const double minimum = 48;
}
