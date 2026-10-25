import '../entities/calendar_date.dart';
import '../entities/cycle.dart';
import '../entities/family.dart';
import '../entities/member.dart';
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
