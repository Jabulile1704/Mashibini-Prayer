import '../entities/calendar_date.dart';
import '../entities/cycle.dart';
import '../entities/family.dart';
import '../entities/member.dart';
import '../entities/skipped_turn.dart';
import '../entities/turn.dart';
import 'week.dart';

/// Answers "whose week is it?" for any date.
///
/// Pure. No clock, no I/O, no Flutter — the date is always an argument, never
/// read from the system, which is what makes every week of the next decade a
/// test case instead of something to wait for.
///
/// The computation, in full:
///
/// ```text
/// weekStart   = the most recent turnover day on or before the date
/// cycle       = the latest cycle whose effectiveFrom <= weekStart
/// weekIndex   = whole weeks from cycle.effectiveFrom to weekStart
/// skipsBefore = skips in that cycle with weekStart <= this weekStart
/// position    = (weekIndex + skipsBefore) mod cycle.order.length
/// ```
///
/// Nothing is advanced and nothing is stored, so a phone that was switched off
/// for six months is exactly as correct as one opened every day (R1.3, ADR-002).
class RotaEngine {
  RotaEngine({
    required this.turnoverWeekday,
    required List<Cycle> cycles,
    required Map<String, Member> members,
    List<SkippedTurn> skips = const <SkippedTurn>[],
  }) : _members = Map<String, Member>.unmodifiable(members),
       _cycles = List<Cycle>.unmodifiable(<Cycle>[...cycles]..sort(_byDate)),
       _skips = List<SkippedTurn>.unmodifiable(skips) {
    Week.assertValidWeekday(turnoverWeekday);
    if (_cycles.isEmpty) {
      throw ArgumentError.value(cycles, 'cycles', 'needs at least one cycle');
    }
    for (final Cycle cycle in _cycles) {
      if (cycle.effectiveFrom.weekday != turnoverWeekday) {
        throw ArgumentError.value(
          cycle.effectiveFrom.toString(),
          'cycle.effectiveFrom',
          'must fall on the turnover weekday ($turnoverWeekday), '
              'but ${cycle.id} starts on a weekday '
              '${cycle.effectiveFrom.weekday}',
        );
      }
    }
  }

  /// Builds an engine for [family].
  ///
  /// The engine takes data; it never fetches any. This factory is the only
  /// place the aggregate and the computation meet.
  factory RotaEngine.forFamily(Family family) => RotaEngine(
    turnoverWeekday: family.turnoverWeekday,
    members: family.membersById,
    cycles: family.cycles,
    skips: family.skips,
  );

  /// Orders cycles by date, and by id when two share a date.
  ///
  /// The id tie-break is not tidiness. Two devices editing the family while
  /// offline can both write an epoch effective from the same turnover, and a
  /// sort that left their order to chance would have the two phones naming
  /// different leaders for the same week. Comparing ids makes the answer the
  /// same everywhere without anything having to coordinate (R6.2).
  static int _byDate(Cycle a, Cycle b) {
    final int byDate = a.effectiveFrom.compareTo(b.effectiveFrom);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  /// ISO weekday the rota hands over on: 1 is Monday, 7 is Sunday.
  final int turnoverWeekday;

  final Map<String, Member> _members;
  final List<Cycle> _cycles;
  final List<SkippedTurn> _skips;

  /// The first day the rota existed. Dates before this have no leader.
  CalendarDate get startedOn => _cycles.first.effectiveFrom;

  /// Member ids referenced by a cycle that no member answers to.
  ///
  /// The order is denormalised, so it can drift from the member list. The
  /// engine drops these rather than crashing; surfacing them here lets the
  /// data layer log a defect without the domain needing to know what a log is.
  Set<String> get unresolvedMemberIds => <String>{
    for (final Cycle cycle in _cycles)
      for (final String id in cycle.order)
        if (!_members.containsKey(id)) id,
  };

  /// Whose week it is on [date], or null if the rota had not started yet.
  ///
  /// Null is the honest answer before [startedOn]: the rota did not exist, so
  /// there is no leader to name. Callers render that state rather than
  /// guessing at one.
  Turn? turnOn(CalendarDate date) {
    final CalendarDate weekStart = Week.startOf(date, turnoverWeekday);
    final Cycle? cycle = _cycleGoverning(weekStart);
    if (cycle == null) {
      return null;
    }

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
      weekEnd: weekStart.addDays(6),
    );
  }

  /// The turn containing [date] and the [count] - 1 turns after it.
  ///
  /// Stops early if the rota has not started. Because each turn is resolved
  /// independently, a cycle change inside the window is handled with no extra
  /// machinery (R1.5).
  List<Turn> turnsFrom(CalendarDate date, {int count = 8}) {
    if (count <= 0) {
      return const <Turn>[];
    }
    final List<Turn> turns = <Turn>[];
    CalendarDate cursor = Week.startOf(date, turnoverWeekday);
    for (int i = 0; i < count; i++) {
      final Turn? turn = turnOn(cursor);
      if (turn == null) {
        break;
      }
      turns.add(turn);
      cursor = cursor.addDays(7);
    }
    return turns;
  }

  /// The latest cycle in force on [weekStart], or null if none had started.
  Cycle? _cycleGoverning(CalendarDate weekStart) {
    Cycle? governing;
    for (final Cycle cycle in _cycles) {
      if (cycle.effectiveFrom.isOnOrBefore(weekStart)) {
        governing = cycle;
      } else {
        break; // sorted, so nothing later can apply
      }
    }
    return governing;
  }

  List<Member> _resolvedOrder(Cycle cycle) => <Member>[
    for (final String id in cycle.order)
      if (_members[id] case final Member member) member,
  ];

  /// Skips inside [cycle] falling on or before [weekStart].
  ///
  /// Bounded below by the cycle's own start so that a skip in an earlier epoch
  /// cannot shift a later one.
  int _skipsUpTo(Cycle cycle, CalendarDate weekStart) {
    int count = 0;
    for (final SkippedTurn skip in _skips) {
      final bool withinEpoch = skip.weekStart.isOnOrAfter(cycle.effectiveFrom);
      final bool notInFuture = skip.weekStart.isOnOrBefore(weekStart);
      if (withinEpoch && notInFuture) {
        count++;
      }
    }
    return count;
  }
}
