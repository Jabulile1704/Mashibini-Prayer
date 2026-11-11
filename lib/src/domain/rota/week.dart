import '../entities/calendar_date.dart';

/// Week arithmetic against a turnover weekday.
abstract final class Week {
  /// The turnover day of the week containing [date].
  static CalendarDate startOf(CalendarDate date, int turnoverWeekday) {
    assertValidWeekday(turnoverWeekday);
    final int daysSinceTurnover = (date.weekday - turnoverWeekday) % 7;
    return date.subtractDays(daysSinceTurnover);
  }

  /// The last day of the week containing [date] — the day before the next
  /// turnover.
  static CalendarDate endOf(CalendarDate date, int turnoverWeekday) =>
      startOf(date, turnoverWeekday).addDays(6);

  /// The first day on or after [date] that falls on [weekday].
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
