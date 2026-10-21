import 'calendar_date.dart';
import 'member.dart';

/// One member's week of leading family prayer.
///
/// A turn is never stored. It is what the engine computes from the cycle, the
/// skips and a date — see ADR-002 for why a stored pointer would be wrong.
class Turn {
  const Turn({
    required this.leader,
    required this.weekStart,
    required this.weekEnd,
  });

  final Member leader;

  /// The turnover day this turn begins on.
  final CalendarDate weekStart;

  /// The last day of the turn — the day before the next turnover.
  final CalendarDate weekEnd;

  bool contains(CalendarDate date) =>
      date.isOnOrAfter(weekStart) && date.isOnOrBefore(weekEnd);

  @override
  bool operator ==(Object other) =>
      other is Turn &&
      other.leader == leader &&
      other.weekStart == weekStart &&
      other.weekEnd == weekEnd;

  @override
  int get hashCode => Object.hash(leader, weekStart, weekEnd);

  @override
  String toString() => 'Turn(${leader.displayName}, $weekStart to $weekEnd)';
}
