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
/// cycle       = the latest cycle whose effectiveFrom <= the start of the
///               date's week *as that cycle counts weeks*
/// weekStart   = the most recent of that cycle's turnover days on or before
///               the date
/// weekEnd     = weekStart + 6, cut short if the next epoch begins first
/// weekIndex   = whole weeks from cycle.effectiveFrom to weekStart
/// skipsBefore = skips in that cycle with weekStart <= this weekStart
/// position    = (weekIndex + skipsBefore) mod cycle.order.length
/// ```
///
/// The first two steps are circular-looking on purpose: each epoch keeps its
/// own turnover day (ADR-019), so a date's week cannot be found before the
/// epoch is, and the epoch cannot be found without slicing weeks. It is
/// resolved by asking the newest epoch first — "does your own week
/// containing this date start on or after you began?" — and taking the first
/// that says yes. For a family that has never moved its turnover day, every
/// epoch answers with the same boundaries and this is the old rule exactly.
///
/// Nothing is advanced and nothing is stored, so a phone that was switched off
/// for six months is exactly as correct as one opened every day (R1.3, ADR-002).
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
  ///
  /// The engine takes data; it never fetches any. This factory is the only
  /// place the aggregate and the computation meet.
  factory RotaEngine.forFamily(Family family) => RotaEngine(
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
  ///
  /// Not a property of the family: a family that moved its turnover day has
  /// dates either side of the change answering differently, which is the
  /// point of moving it by epoch (ADR-019). Returns the latest epoch's day
  /// for a date before the rota started, since there is no epoch to ask and
  /// the caller is laying out a calendar rather than naming a leader.
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
  ///
  /// Never null. A rota has at least one epoch — the constructor refuses
  /// otherwise — so "which order is in force" always has an answer, even for
  /// a date on which nobody was leading yet.
  Cycle cycleFor(CalendarDate date) {
    final int governing = _indexGoverning(date);
    return governing < 0 ? _cycles.first : _cycles[governing];
  }

  /// The last day of the week starting on [weekStart], normally six days
  /// later.
  ///
  /// Cut short when a later epoch begins inside it. That happens exactly when
  /// the family moved the turnover day: the new day is one to six days after
  /// the old week would have ended, so the last week of the old epoch is one
  /// to six days short. The alternative to shortening it is a week whose last
  /// day belongs to two turns at once — which the screens would show as one
  /// date appearing in two people's weeks.
  ///
  /// Nobody loses a turn to this. `FamilyEditor.changeTurnoverDay` starts the
  /// new epoch's order at the person *after* whoever leads the short week, so
  /// the short week is a turn taken, not a turn missed.
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
  ///
  /// Stops early if the rota has not started. Because each turn is resolved
  /// independently, a cycle change inside the window is handled with no extra
  /// machinery (R1.5).
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
      // Not `+ 7`. Across an epoch that moved the turnover day, seven days
      // from a week start lands inside the next week rather than on it, and
      // a short week would be walked past entirely. The day after this turn
      // ends is the next turn's first day by definition, whatever its
      // length, and `turnOn` normalises from any date in a week anyway.
      cursor = turn.weekEnd.addDays(1);
    }
    return turns;
  }

  /// Index into [_cycles] of the epoch governing [date], or -1 if the rota
  /// had not started.
  ///
  /// Asks the newest epoch first. Each candidate slices the week around
  /// [date] with **its own** turnover day and is accepted if it had begun by
  /// the start of that week; the newest to accept wins. Walking newest-first
  /// is what makes the answer well defined when two epochs disagree about
  /// where the week boundary is — the later decision is the one the family
  /// made most recently.
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
  ///
  /// Bounded below by the cycle's own start so that a skip in an earlier epoch
  /// cannot shift a later one.
  ///
  /// Withdrawn skips are not counted. They stay in the log because that is
  /// how two phones agree one was taken back (ADR-012), but a skip somebody
  /// changed their mind about must not move the rota.
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
