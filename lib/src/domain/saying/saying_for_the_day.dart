import '../entities/calendar_date.dart';
import '../entities/saying.dart';

/// Picks the saying for a date.
class SayingForTheDay {
  SayingForTheDay({required List<Saying> sayings, required this.source})
    : _sayings = List<Saying>.unmodifiable(sayings) {
    if (_sayings.isEmpty) {
      throw ArgumentError.value(sayings, 'sayings', 'cannot be empty');
    }
  }

  final List<Saying> _sayings;
  final SayingSource source;

  int get count => _sayings.length;

  /// How long before the list repeats.
  int get daysUntilRepeat => _sayings.length;

  Saying on(CalendarDate date) => _sayings[_indexFor(date)];

  /// Days since 1 January 1970, modulo the number of sayings.
  int _indexFor(CalendarDate date) {
    const int epochYear = 1970;
    final int days = CalendarDate(epochYear, 1, 1).daysUntil(date);
    return days % _sayings.length;
  }
}
