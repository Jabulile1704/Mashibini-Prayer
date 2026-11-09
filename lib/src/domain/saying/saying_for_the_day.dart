import '../entities/calendar_date.dart';
import '../entities/saying.dart';

/// Picks the saying for a date.
///
/// Every member of the family must see the same saying on the same day (R3.1),
/// and they are four people on four phones that may never be online at the
/// same moment. So the choice cannot be made by a server, or stored, or
/// randomised with a shared seed that has to be distributed.
///
/// It is arithmetic on the date instead — the same reasoning as the rota
/// (ADR-002). Nothing to coordinate, nothing to advance, and a phone that has
/// been off for a month shows the right saying the moment it opens.
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
  ///
  /// An epoch-day count rather than a hash: it moves by exactly one each day,
  /// so consecutive days are consecutive sayings and the set is walked in
  /// order rather than sampled with repeats. Somebody opening the app two
  /// days running should not see the same saying because a hash collided.
  int _indexFor(CalendarDate date) {
    const int epochYear = 1970;
    final int days = CalendarDate(epochYear, 1, 1).daysUntil(date);
    return days % _sayings.length;
  }
}
