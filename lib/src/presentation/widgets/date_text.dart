import 'package:flutter/material.dart';

import '../../domain/entities/calendar_date.dart';

/// Date formatting, in one place.
///
/// Uses `MaterialLocalizations` rather than a package: it is already in the
/// box and it follows the device's locale. The app asks for `en_ZA` first
/// (see `AppLocales`), because Flutter's default formats a full date
/// American-style and this rota is read in South Africa.
///
/// Three formats, each added when a screen needed it rather than in advance:
/// the full date for the rota, and a month heading and a short date for the
/// journal.
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
