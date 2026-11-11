import 'calendar_date.dart';
import 'member.dart';

/// One member's week of leading family prayer.
class Turn {
  const Turn({
    required this.leader,
    required this.weekStart,
    required this.weekEnd,
    this.position = 0,
    this.cycleLength = 1,
  });

  final Member leader;

  /// The turnover day this turn begins on.
  final CalendarDate weekStart;

  /// The last day of the turn — the day before the next turnover.
  final CalendarDate weekEnd;

  /// Where this turn sits in the cycle, counting from zero.
  final int position;

  /// How many people are in the cycle this turn belongs to.
  final int cycleLength;

  bool contains(CalendarDate date) =>
      date.isOnOrAfter(weekStart) && date.isOnOrBefore(weekEnd);

  @override
  bool operator ==(Object other) =>
      other is Turn &&
      other.leader == leader &&
      other.weekStart == weekStart &&
      other.weekEnd == weekEnd &&
      other.position == position &&
      other.cycleLength == cycleLength;

  @override
  int get hashCode =>
      Object.hash(leader, weekStart, weekEnd, position, cycleLength);

  @override
  String toString() => 'Turn(${leader.displayName}, $weekStart to $weekEnd)';
}
