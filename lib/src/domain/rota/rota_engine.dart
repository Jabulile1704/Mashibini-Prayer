import '../entities/calendar_date.dart';
import '../entities/cycle.dart';
import '../entities/family.dart';
import '../entities/member.dart';
import '../entities/skipped_turn.dart';
import '../entities/turn.dart';
import 'week.dart';

/// Answers "whose week is it?" for any date.
class RotaEngine {
  RotaEngine({
    required List<Cycle> cycles,
    required Map<String, Member> members,
    List<SkippedTurn> skips = const <SkippedTurn>[],
  }) : _members = Map<String, Member>.unmodifiable(members),
       _cycles = List<Cycle>.unmodifiable(<Cycle>[...cycles]..sort(_byDate)),
       _skips = List<SkippedTurn>.unmodifiable(skips) {
    if (_cycles.isEmpty) {
      throw ArgumentError.value(cycles, 'cycles', 'needs at least one cycle');
    }
  }

  /// Builds an engine for [family].
  factory RotaEngine.forFamily(Family family) => RotaEngine(
    members: family.membersById,
    cycles: family.cycles,
    skips: family.skips,
  );

  /// Orders cycles by date, and by id when two share a date.
  static int _byDate(Cycle a, Cycle b) {
    final int byDate = a.effectiveFrom.compareTo(b.effectiveFrom);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  final Map<String, Member> _members;
  final List<Cycle> _cycles;
  final List<SkippedTurn> _skips;

  /// The first day the rota existed. Dates before this have no leader.
  CalendarDate get startedOn => _cycles.first.effectiveFrom;

  /// Member ids referenced by a cycle that no member answers to.
  Set<String> get unresolvedMemberIds => <String>{
    for (final Cycle cycle in _cycles)
      for (final String id in cycle.order)
        if (!_members.containsKey(id)) id,
  };

  /// Whose week it is on [date], or null if the rota had not started yet.
  Turn? turnOn(CalendarDate date) {
    final int governing = _indexGoverning(date);
    if (governing < 0) {
      return null;
    }
    final Cycle cycle = _cycles[governing];
    final CalendarDate weekStart = Week.startOf(date, cycle.turnoverWeekday);

    final List<Member> order = _resolvedOrder(cycle);
    if (order.isEmpty) {
      return null;
    }

    final int weekIndex = Week.between(cycle.effectiveFrom, weekStart);
    final int skipsBefore = _skipsUpTo(cycle, weekStart);
    final int position = (weekIndex + skipsBefore) % order.length;

    return Turn(
      leader: order[position],
      weekStart: weekStart,
      weekEnd: _endOfWeekStarting(weekStart, after: governing),
      position: position,
      cycleLength: order.length,
    );
  }

  /// Which day the week turns over on for whoever leads on [date].
  int turnoverWeekdayOn(CalendarDate date) {
    final int governing = _indexGoverning(date);
    return governing < 0
        ? _cycles.last.turnoverWeekday
        : _cycles[governing].turnoverWeekday;
  }

  /// The first day of the week containing [date].
  CalendarDate weekStartOn(CalendarDate date) =>
      Week.startOf(date, turnoverWeekdayOn(date));

  /// The epoch governing [date], or the earliest one for a date before the
  /// rota started.
  Cycle cycleFor(CalendarDate date) {
    final int governing = _indexGoverning(date);
    return governing < 0 ? _cycles.first : _cycles[governing];
  }

  /// The last day of the week starting on [weekStart], normally six days
  /// later.
  CalendarDate _endOfWeekStarting(
    CalendarDate weekStart, {
    required int after,
  }) {
    final CalendarDate end = weekStart.addDays(6);
    if (after + 1 >= _cycles.length) {
      return end;
    }
    final CalendarDate nextEpochBegins = _cycles[after + 1].effectiveFrom;
    final CalendarDate lastDayBefore = nextEpochBegins.subtractDays(1);
    return lastDayBefore.isBefore(end) ? lastDayBefore : end;
  }

  /// The turn containing [date] and the [count] - 1 turns after it.
  List<Turn> turnsFrom(CalendarDate date, {int count = 8}) {
    if (count <= 0) {
      return const <Turn>[];
    }
    final List<Turn> turns = <Turn>[];
    CalendarDate cursor = date;
    for (int i = 0; i < count; i++) {
      final Turn? turn = turnOn(cursor);
      if (turn == null) {
        break;
      }
      turns.add(turn);
      cursor = turn.weekEnd.addDays(1);
    }
    return turns;
  }

  /// Index into [_cycles] of the epoch governing [date], or -1 if the rota
  /// had not started.
  int _indexGoverning(CalendarDate date) {
    for (int i = _cycles.length - 1; i >= 0; i--) {
      final Cycle cycle = _cycles[i];
      final CalendarDate weekStart = Week.startOf(date, cycle.turnoverWeekday);
      if (cycle.effectiveFrom.isOnOrBefore(weekStart)) {
        return i;
      }
    }
    return -1;
  }

  List<Member> _resolvedOrder(Cycle cycle) => <Member>[
    for (final String id in cycle.order)
      if (_members[id] case final Member member) member,
  ];

  /// Skips inside [cycle] falling on or before [weekStart].
  int _skipsUpTo(Cycle cycle, CalendarDate weekStart) {
    int count = 0;
    for (final SkippedTurn skip in _skips) {
      if (skip.withdrawn) {
        continue;
      }
      final bool withinEpoch = skip.weekStart.isOnOrAfter(cycle.effectiveFrom);
      final bool notInFuture = skip.weekStart.isOnOrBefore(weekStart);
      if (withinEpoch && notInFuture) {
        count++;
      }
    }
    return count;
  }
}
