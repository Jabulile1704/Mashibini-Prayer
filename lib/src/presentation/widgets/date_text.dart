import 'package:flutter/material.dart';

import '../../domain/entities/calendar_date.dart';

/// Date formatting, in one place.
///
/// Uses `MaterialLocalizations` rather than a package: it is already in the
/// box and it follows the device's locale. The app asks for `en_ZA` first
/// (see `AppLocales`), because Flutter's default formats a full date
/// American-style and this rota is read in South Africa.
///
/// One format, because one is what is used. The schedule list will want a
/// shorter one (R1.5, day 12); it can be added then, by someone who can see
/// what it needs to look like.
abstract final class DateLabels {
  /// "Sunday 25 October 2026" — for a date the reader must not misread.
  static String full(BuildContext context, CalendarDate date) =>
      MaterialLocalizations.of(context).formatFullDate(date.toLocalDateTime());
}
