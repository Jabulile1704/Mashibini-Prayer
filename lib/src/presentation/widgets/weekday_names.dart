/// Weekday names for the turnover picker.
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
