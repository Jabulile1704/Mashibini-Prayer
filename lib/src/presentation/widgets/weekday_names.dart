/// Weekday names for the turnover picker.
///
/// Hard-coded English rather than reached for from a package, because
/// `AppLocales` declares this app supports English only. `MaterialLocalizations`
/// has no weekday-name API — only narrow initials — and adding `intl` for
/// seven strings would be a dependency bought with a shrug.
///
/// **If a non-English locale is ever added to `AppLocales`, this is the first
/// thing that has to change**, and it will be obviously wrong rather than
/// subtly wrong, which is the best a hard-coded string can offer.
abstract final class WeekdayNames {
  /// Indexed by ISO weekday: 1 is Monday, 7 is Sunday.
  static const Map<int, String> byIsoWeekday = <int, String>{
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };
}
