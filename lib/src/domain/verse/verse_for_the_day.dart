import '../entities/calendar_date.dart';
import '../entities/verse.dart';

/// Picks the verse for a date.
///
/// Every member of the family must see the same verse on the same day (R3.1),
/// and they are four people on four phones that may never be online at the
/// same moment. So the choice cannot be made by a server, or stored, or
/// randomised with a shared seed that has to be distributed.
///
/// It is arithmetic on the date instead — the same reasoning as the rota
/// (ADR-002). Nothing to coordinate, nothing to advance, and a phone that has
/// been off for a month shows the right verse the moment it opens.
class VerseForTheDay {
  VerseForTheDay({required List<Verse> verses, required this.translation})
    : _verses = List<Verse>.unmodifiable(verses) {
    if (_verses.isEmpty) {
      throw ArgumentError.value(verses, 'verses', 'cannot be empty');
    }
  }

  final List<Verse> _verses;
  final Translation translation;

  int get count => _verses.length;

  /// How long before the list repeats.
  int get daysUntilRepeat => _verses.length;

  Verse on(CalendarDate date) => _verses[_indexFor(date)];

  /// Days since 1 January 1970, modulo the number of verses.
  ///
  /// An epoch-day count rather than a hash: it moves by exactly one each day,
  /// so consecutive days are consecutive verses and the set is walked in
  /// order rather than sampled with repeats. Somebody opening the app two
  /// days running should not see the same verse because a hash collided.
  int _indexFor(CalendarDate date) {
    const int epochYear = 1970;
    final int days = CalendarDate(epochYear, 1, 1).daysUntil(date);
    return days % _verses.length;
  }
}
