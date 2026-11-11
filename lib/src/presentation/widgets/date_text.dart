import 'package:flutter/material.dart';

import '../../domain/entities/calendar_date.dart';

/// Date formatting, in one place.
abstract final class DateLabels {
  /// "Sunday 25 October 2026" — for a date the reader must not misread.
  static String full(BuildContext context, CalendarDate date) =>
      MaterialLocalizations.of(context).formatFullDate(date.toLocalDateTime());

  /// "October 2026" — the heading over a month of journal entries.
  static String monthAndYear(BuildContext context, CalendarDate date) =>
      MaterialLocalizations.of(context).formatMonthYear(date.toLocalDateTime());

  /// "Wed, 28 Oct" — enough to place an entry without repeating the year
  /// that its month heading already gave.
  static String dayAndDate(BuildContext context, CalendarDate date) =>
      MaterialLocalizations.of(context)
          .formatMediumDate(date.toLocalDateTime());
}
