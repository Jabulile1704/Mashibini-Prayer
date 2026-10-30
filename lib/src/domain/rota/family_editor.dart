import '../entities/calendar_date.dart';
import '../entities/cycle.dart';
import '../entities/family.dart';
import '../entities/member.dart';
import '../entities/skipped_turn.dart';
import '../entities/turn.dart';
import '../ids.dart';
import 'rota_engine.dart';
import 'week.dart';

/// Changing the family without rewriting its history.
///
/// Every change writes a **new cycle epoch** rather than editing the current
/// one, which is the whole reason cycles are versioned (ADR-002, R2.3). Past
/// dates keep resolving against the epoch that was in force, so a turn that
/// has already happened keeps the name of the person who actually led it.
///
/// Two rules shape all of this:
///
/// **Changes take effect at the next turnover, never mid-week.** Somebody's
/// week should not change under them because a name was added on a Wednesday.
///
/// **The week after a change keeps the leader it was already going to have.**
/// The new epoch's order is rotated to begin with whoever the old cycle said
/// leads that week, so adding or removing a person never silently reassigns
/// the next turn to somebody else.
abstract final class FamilyEditor {
  /// Adds a person, joining at the end of the cycle (R2.3).
  ///
  /// They lead last: everyone already in the rota takes their turn first,
  /// starting from the next turnover.
  static Family addMember(
    Family family, {
    required String displayName,
    required CalendarDate today,
    required IdGenerator ids,
  }) {
    final String name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'cannot be empty');
    }

    final Member joining = Member(id: ids.newId('m'), displayName: name);
    final List<String> order = <String>[
      ..._orderFromNextTurnover(family, today),
      joining.id,
    ];

    return _withNewCycle(
      family,
      today: today,
      order: order,
      reason: CycleReason.memberAdded,
      members: <Member>[...family.members, joining],
      ids: ids,
    );
  }

  /// Removes a person from future turns (R2.3).
  ///
  /// They stay in [Family.members] on purpose: past epochs still reference
  /// them, and a turn they led in March must keep their name rather than
  /// become a blank. Whether somebody is *currently* in the rota is answered
  /// by the current cycle's order, so there is no second flag to disagree
  /// with it.
  static Family removeMember(
    Family family, {
    required String memberId,
    required CalendarDate today,
    required IdGenerator ids,
  }) {
    final List<String> current = _orderFromNextTurnover(family, today);
    if (!current.contains(memberId)) {
      throw ArgumentError.value(
        memberId,
        'memberId',
        'is not in the current rota',
      );
    }
    if (current.length <= 2) {
      throw ArgumentError.value(
        memberId,
        'memberId',
        'a rota needs at least two people; removing this one would leave '
            '${current.length - 1}',
      );
    }

    return _withNewCycle(
      family,
      today: today,
      order: <String>[
        for (final String id in current)
          if (id != memberId) id,
      ],
      reason: CycleReason.memberRemoved,
      members: family.members,
      ids: ids,
    );
  }

  /// Passes over the turn starting on [weekStart] (R1.4).
  ///
  /// The week's leader loses it and everybody after moves up one. They are
  /// **not owed a double turn** when the cycle comes round again: the engine
  /// counts skips into the position, so the whole rota shifts rather than two
  /// people swapping. R1.4 calls that forgiveness rather than debt, and it is
  /// the reason this is a log entry and not a rearranged order.
  ///
  /// **Only a week that has not started yet.** The week in progress is
  /// refused, including on its own turnover day. By then the week is somebody
  /// else's as far as the family is concerned — they may already have led on
  /// Sunday — and a record saying it was passed over would make the app
  /// disagree with what actually happened. Skipping is for a turn ahead; a
  /// week that has gone wrong is not a data problem.
  static Family skipTurn(
    Family family, {
    required CalendarDate weekStart,
    required CalendarDate today,
    required IdGenerator ids,
  }) {
    final CalendarDate thisWeek = Week.startOf(today, family.turnoverWeekday);
    if (weekStart.isOnOrBefore(thisWeek)) {
      throw ArgumentError.value(
        weekStart,
        'weekStart',
        'has already started; only a turn still ahead can be skipped',
      );
    }
    if (weekStart != Week.startOf(weekStart, family.turnoverWeekday)) {
      throw ArgumentError.value(
        weekStart,
        'weekStart',
        'is not a turnover day for this family',
      );
    }

    final Turn? turn = RotaEngine.forFamily(family).turnOn(weekStart);
    if (turn == null) {
      throw ArgumentError.value(
        weekStart,
        'weekStart',
        'has no turn to skip; the rota does not run that week',
      );
    }
    if (skipOn(family, weekStart) != null) {
      throw ArgumentError.value(weekStart, 'weekStart', 'is already skipped');
    }

    return _copyWithSkips(family, <SkippedTurn>[
      ...family.skips,
      SkippedTurn(
        id: ids.newId('s'),
        weekStart: weekStart,
        memberId: turn.leader.id,
      ),
    ]);
  }

  /// Takes back the skip on [weekStart], restoring that week's leader.
  ///
  /// The record stays, marked withdrawn, rather than being removed. Skips
  /// merge by union across devices, so a deletion on one phone would be
  /// undone by the other's copy; a withdrawal merges in one direction and
  /// survives (ADR-012).
  static Family unskipTurn(Family family, {required CalendarDate weekStart}) {
    final SkippedTurn? skip = skipOn(family, weekStart);
    if (skip == null) {
      throw ArgumentError.value(weekStart, 'weekStart', 'is not skipped');
    }

    return _copyWithSkips(family, <SkippedTurn>[
      for (final SkippedTurn existing in family.skips)
        if (existing.id == skip.id) existing.withdraw() else existing,
    ]);
  }

  /// The skip standing against [weekStart], or null if that week is running.
  ///
  /// Withdrawn records are not skips any more, so they do not answer here —
  /// which is what lets a week be skipped, taken back, and skipped again.
  static SkippedTurn? skipOn(Family family, CalendarDate weekStart) {
    for (final SkippedTurn skip in family.skips) {
      if (!skip.withdrawn && skip.weekStart == weekStart) {
        return skip;
      }
    }
    return null;
  }

  static Family _copyWithSkips(Family family, List<SkippedTurn> skips) =>
      Family(
        id: family.id,
        name: family.name,
        turnoverWeekday: family.turnoverWeekday,
        members: family.members,
        cycles: family.cycles,
        skips: skips,
        schemaVersion: family.schemaVersion,
      );

  /// Who is in the rota right now, as the current cycle has it.
  static List<Member> activeMembers(Family family, CalendarDate today) {
    final Cycle cycle = _cycleOn(
      family,
      Week.startOf(today, family.turnoverWeekday),
    );
    final Map<String, Member> byId = family.membersById;
    return <Member>[
      for (final String id in cycle.order)
        if (byId[id] case final Member member) member,
    ];
  }

  /// The order for the epoch starting at the next turnover, rotated so that
  /// it begins with whoever was already due to lead that week.
  static List<String> _orderFromNextTurnover(
    Family family,
    CalendarDate today,
  ) {
    final CalendarDate nextTurnover = Week.startOf(
      today,
      family.turnoverWeekday,
    ).addDays(7);

    final Cycle cycle = _cycleOn(family, nextTurnover);
    final RotaEngine engine = RotaEngine.forFamily(family);
    final Member? nextLeader = engine.turnOn(nextTurnover)?.leader;

    if (nextLeader == null) {
      return List<String>.of(cycle.order);
    }
    final int at = cycle.order.indexOf(nextLeader.id);
    if (at <= 0) {
      return List<String>.of(cycle.order);
    }
    return <String>[
      for (int i = 0; i < cycle.order.length; i++)
        cycle.order[(at + i) % cycle.order.length],
    ];
  }

  static Cycle _cycleOn(Family family, CalendarDate weekStart) {
    final List<Cycle> sorted = <Cycle>[...family.cycles]
      ..sort((Cycle a, Cycle b) => a.effectiveFrom.compareTo(b.effectiveFrom));
    Cycle governing = sorted.first;
    for (final Cycle cycle in sorted) {
      if (cycle.effectiveFrom.isOnOrBefore(weekStart)) {
        governing = cycle;
      }
    }
    return governing;
  }

  static Family _withNewCycle(
    Family family, {
    required CalendarDate today,
    required List<String> order,
    required CycleReason reason,
    required List<Member> members,
    required IdGenerator ids,
  }) {
    final CalendarDate from = Week.startOf(
      today,
      family.turnoverWeekday,
    ).addDays(7);

    return Family(
      id: family.id,
      name: family.name,
      turnoverWeekday: family.turnoverWeekday,
      members: members,
      cycles: <Cycle>[
        ...family.cycles,
        Cycle(
          id: ids.newId('c'),
          effectiveFrom: from,
          order: order,
          reason: reason,
        ),
      ],
      skips: family.skips,
      schemaVersion: family.schemaVersion,
    );
  }
}
