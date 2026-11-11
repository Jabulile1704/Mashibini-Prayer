/// A date on a calendar, with no time of day and no timezone.
class CalendarDate implements Comparable<CalendarDate> {
  /// The date of [year], [month] and [day].
  CalendarDate(int year, int month, int day)
    : _at = DateTime.utc(year, month, day);

  CalendarDate._(this._at);

  /// The calendar date [moment] falls on, in the local timezone.
  factory CalendarDate.from(DateTime moment) =>
      CalendarDate(moment.year, moment.month, moment.day);

  /// Parses an ISO `yyyy-mm-dd` string, the form the database stores.
  factory CalendarDate.parse(String iso) {
    final RegExp shape = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
    final RegExpMatch? match = shape.firstMatch(iso);
    if (match == null) {
      throw FormatException('Expected yyyy-mm-dd', iso);
    }
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    final CalendarDate date = CalendarDate(year, month, day);
    // Reject 2026-02-31 rather than silently rolling it into March.
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('Not a real date', iso);
    }
    return date;
  }

  final DateTime _at;

  int get year => _at.year;
  int get month => _at.month;
  int get day => _at.day;

  /// ISO-8601 weekday: 1 is Monday, 7 is Sunday.
  int get weekday => _at.weekday;

  CalendarDate addDays(int days) =>
      CalendarDate._(_at.add(Duration(days: days)));

  CalendarDate subtractDays(int days) => addDays(-days);

  /// Whole days from this date to [other]. Negative if [other] is earlier.
  int daysUntil(CalendarDate other) => other._at.difference(_at).inDays;

  bool isBefore(CalendarDate other) => _at.isBefore(other._at);

  bool isAfter(CalendarDate other) => _at.isAfter(other._at);

  bool isOnOrBefore(CalendarDate other) => !isAfter(other);

  bool isOnOrAfter(CalendarDate other) => !isBefore(other);

  /// This date as a local [DateTime] at midnight, **for display only**.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  @override
  int compareTo(CalendarDate other) => _at.compareTo(other._at);

  @override
  bool operator ==(Object other) => other is CalendarDate && other._at == _at;

  @override
  int get hashCode => _at.hashCode;

  /// ISO `yyyy-mm-dd` — the form the database stores.
  @override
  String toString() {
    final String m = month.toString().padLeft(2, '0');
    final String d = day.toString().padLeft(2, '0');
    return '$year-$m-$d';
  }
}
