import '../entities/calendar_date.dart';

/// Week arithmetic against a turnover weekday.
///
/// The family's week does not start on Monday; it starts on whichever day
/// they hand the rota over. Every date question in this app is really a
/// question about which of those weeks a date falls in.
abstract final class Week {
  /// The turnover day of the week containing [date].
  ///
  /// If [date] is itself a turnover day, it is its own week start — the
  /// handover takes effect at the start of the day, not at some hour in it
  /// (R1.2).
  static CalendarDate startOf(CalendarDate date, int turnoverWeekday) {
    assertValidWeekday(turnoverWeekday);
    // Dart's % returns a non-negative result for a positive divisor, so this
    // is correct even when the weekday is "behind" the turnover.
    final int daysSinceTurnover = (date.weekday - turnoverWeekday) % 7;
    return date.subtractDays(daysSinceTurnover);
  }

  /// The last day of the week containing [date] — the day before the next
  /// turnover.
  static CalendarDate endOf(CalendarDate date, int turnoverWeekday) =>
      startOf(date, turnoverWeekday).addDays(6);

  /// The first day on or after [date] that falls on [weekday].
  ///
  /// Returns [date] itself when it already does. Used when the family changes
  /// the day the week turns over and the new epoch has to start on the first
  /// one of those days — which is between one and six days after the old
  /// week would have ended, because the calendar does not divide evenly.
  static CalendarDate onOrAfter(CalendarDate date, int weekday) {
    assertValidWeekday(weekday);
    return date.addDays((weekday - date.weekday) % 7);
  }

  /// Whole weeks from [from] to [to]. Both must be turnover days.
  static int between(CalendarDate from, CalendarDate to) =>
      from.daysUntil(to) ~/ 7;

  static void assertValidWeekday(int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) {
      throw ArgumentError.value(
        weekday,
        'weekday',
        'Must be an ISO weekday, 1 (Monday) to 7 (Sunday)',
      );
    }
  }
}
