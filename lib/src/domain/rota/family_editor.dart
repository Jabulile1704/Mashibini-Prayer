import '../entities/calendar_date.dart';
import '../entities/cycle.dart';
import '../entities/family.dart';
import '../entities/member.dart';
import '../entities/skipped_turn.dart';
import '../entities/song.dart';
import '../entities/turn.dart';
import '../family/family_tree.dart';
import '../ids.dart';
import 'rota_engine.dart';
import 'week.dart';

/// Changing the family without rewriting its history.
abstract final class FamilyEditor {
  /// Adds a person, joining at the end of the cycle (R2.3).
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

  /// Moves the day the week turns over on (R1.2, #100).
  static Family changeTurnoverDay(
    Family family, {
    required int weekday,
    required CalendarDate today,
    required IdGenerator ids,
  }) {
    Week.assertValidWeekday(weekday);

    if (family.turnoverWeekday == weekday) {
      throw ArgumentError.value(
        weekday,
        'weekday',
        'is already the day the week turns over on',
      );
    }

    final RotaEngine engine = RotaEngine.forFamily(family);
    final CalendarDate notBefore = _laterOf(
      _nextTurnover(engine, today),
      family.latestCycle.effectiveFrom.addDays(1),
    );
    final CalendarDate from = Week.onOrAfter(notBefore, weekday);

    final CalendarDate dayBefore = from.subtractDays(1);
    final List<String> order = engine.cycleFor(dayBefore).order;

    return Family(
      id: family.id,
      name: family.name,
      members: family.members,
      cycles: <Cycle>[
        ...family.cycles,
        Cycle(
          id: ids.newId('c'),
          effectiveFrom: from,
          order: _rotatedToStartWith(
            order,
            _after(order, engine.turnOn(dayBefore)?.leader.id),
          ),
          reason: CycleReason.turnoverDayChanged,
        ),
      ],
      skips: family.skips,
      schemaVersion: family.schemaVersion,
    );
  }

  static CalendarDate _laterOf(CalendarDate a, CalendarDate b) =>
      a.isAfter(b) ? a : b;

  /// Whoever takes their turn after [id], or null if [id] is not in [order].
  static String? _after(List<String> order, String? id) {
    final int at = id == null ? -1 : order.indexOf(id);
    return at < 0 ? null : order[(at + 1) % order.length];
  }

  /// Passes over the turn starting on [weekStart] (R1.4).
  static Family skipTurn(
    Family family, {
    required CalendarDate weekStart,
    required CalendarDate today,
    required IdGenerator ids,
  }) {
    final RotaEngine engine = RotaEngine.forFamily(family);
    final CalendarDate thisWeek = engine.weekStartOn(today);
    if (weekStart.isOnOrBefore(thisWeek)) {
      throw ArgumentError.value(
        weekStart,
        'weekStart',
        'has already started; only a turn still ahead can be skipped',
      );
    }
    if (weekStart != engine.weekStartOn(weekStart)) {
      throw ArgumentError.value(
        weekStart,
        'weekStart',
        'is not a turnover day for this family',
      );
    }

    final Turn? turn = engine.turnOn(weekStart);
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

  /// Adds somebody to the **family** without putting them in the rota (#109).
  static Family addRelative(
    Family family, {
    required String displayName,
    required IdGenerator ids,
    String? role,
    List<String> parentIds = const <String>[],
  }) {
    final String name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'cannot be empty');
    }

    return family.copyWith(
      members: <Member>[
        ...family.members,
        Member(
          id: ids.newId('m'),
          displayName: name,
          role: role?.trim().isEmpty ?? true ? null : role!.trim(),
          parentIds: <String>[
            for (final String id in parentIds)
              if (family.membersById.containsKey(id)) id,
          ],
        ),
      ],
    );
  }

  /// Replaces one member with [updated], leaving the rota untouched.
  static Family updateMember(Family family, Member updated) {
    if (!family.membersById.containsKey(updated.id)) {
      throw ArgumentError.value(
        updated.id,
        'updated.id',
        'is not in this family',
      );
    }
    for (final String parentId in updated.parentIds) {
      if (FamilyTree.wouldMakeALoop(
        family.members,
        childId: updated.id,
        parentId: parentId,
      )) {
        throw ArgumentError.value(
          parentId,
          'parentIds',
          'would make ${updated.displayName} their own ancestor',
        );
      }
    }

    return family.copyWith(
      members: <Member>[
        for (final Member member in family.members)
          if (member.id == updated.id) updated else member,
      ],
    );
  }

  /// When a change made on [today] would take effect.
  static CalendarDate changesTakeEffect(Family family, CalendarDate today) =>
      _nextTurnover(RotaEngine.forFamily(family), today);

  /// Ties a signed-in account to one member of the family (#76, ADR-023).
  static Family linkUid(
    Family family, {
    required String memberId,
    required String uid,
  }) {
    final Member? member = family.membersById[memberId];
    if (member == null) {
      throw ArgumentError.value(memberId, 'memberId', 'is not in this family');
    }
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'cannot be empty');
    }

    for (final Member other in family.members) {
      if (other.uid == uid && other.id != memberId) {
        throw ArgumentError.value(
          uid,
          'uid',
          'already belongs to ${other.displayName}; sign out on that phone '
              'or choose the right name',
        );
      }
    }

    if (member.uid == uid) {
      return family;
    }

    return family.copyWith(
      members: <Member>[
        for (final Member each in family.members)
          if (each.id == memberId) each.copyWith(uid: uid) else each,
      ],
    );
  }

  /// Takes the account off a member, so another can be linked.
  static Family unlinkUid(Family family, {required String memberId}) {
    final Member? member = family.membersById[memberId];
    if (member == null) {
      throw ArgumentError.value(memberId, 'memberId', 'is not in this family');
    }
    if (member.uid == null) {
      return family;
    }
    return family.copyWith(
      members: <Member>[
        for (final Member each in family.members)
          if (each.id == memberId)
            Member(
              id: each.id,
              displayName: each.displayName,
              role: each.role,
              photoPath: each.photoPath,
              parentIds: each.parentIds,
            )
          else
            each,
      ],
    );
  }

  /// Which member, if any, this account is already tied to.
  static Member? memberFor(Family family, String uid) {
    for (final Member member in family.members) {
      if (member.uid == uid) {
        return member;
      }
    }
    return null;
  }

  /// Adds a song to the family's book (#110).
  static Family addSong(
    Family family, {
    required String title,
    required String addedBy,
    required CalendarDate today,
    required IdGenerator ids,
    String? performer,
    String? link,
  }) {
    final String name = title.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(title, 'title', 'cannot be empty');
    }
    if (!family.membersById.containsKey(addedBy)) {
      throw ArgumentError.value(addedBy, 'addedBy', 'is not in this family');
    }

    return family.copyWith(
      songs: <Song>[
        ...family.songs,
        Song(
          id: ids.newId('song'),
          title: name,
          performer: _orNull(performer),
          addedBy: addedBy,
          addedOn: today,
          link: _orNull(link),
        ),
      ],
    );
  }

  /// Takes a song out of the book.
  static Family removeSong(Family family, {required String songId}) {
    final bool known = family.songs.any((Song s) => s.id == songId);
    if (!known) {
      throw ArgumentError.value(songId, 'songId', 'is not in the songbook');
    }
    return family.copyWith(
      songs: <Song>[
        for (final Song song in family.songs)
          if (song.id == songId) song.remove() else song,
      ],
    );
  }

  /// The songs still in the book, newest first.
  static List<Song> songbook(Family family) {
    final List<Song> kept = <Song>[
      for (final Song song in family.songs)
        if (!song.removed) song,
    ];
    kept.sort((Song a, Song b) {
      final int byDate = b.addedOn.compareTo(a.addedOn);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return kept;
  }

  static String? _orNull(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The skip standing against [weekStart], or null if that week is running.
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
        members: family.members,
        cycles: family.cycles,
        skips: skips,
        schemaVersion: family.schemaVersion,
      );

  /// Who is in the rota right now, as the current cycle has it.
  static List<Member> activeMembers(Family family, CalendarDate today) {
    final Cycle cycle = RotaEngine.forFamily(family).cycleFor(today);
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
    final RotaEngine engine = RotaEngine.forFamily(family);
    final CalendarDate nextTurnover = _nextTurnover(engine, today);
    final Cycle cycle = engine.cycleFor(nextTurnover);
    final Member? nextLeader = engine.turnOn(nextTurnover)?.leader;

    return _rotatedToStartWith(cycle.order, nextLeader?.id);
  }

  /// The day the week after [today]'s begins.
  static CalendarDate _nextTurnover(RotaEngine engine, CalendarDate today) {
    final Turn? current = engine.turnOn(today);
    return current != null
        ? current.weekEnd.addDays(1)
        : engine.weekStartOn(today).addDays(7);
  }

  /// [order] rotated so that [first] leads it.
  static List<String> _rotatedToStartWith(List<String> order, String? first) {
    final int at = first == null ? -1 : order.indexOf(first);
    if (at <= 0) {
      return List<String>.of(order);
    }
    return <String>[
      for (int i = 0; i < order.length; i++) order[(at + i) % order.length],
    ];
  }

  static Family _withNewCycle(
    Family family, {
    required CalendarDate today,
    required List<String> order,
    required CycleReason reason,
    required List<Member> members,
    required IdGenerator ids,
  }) {
    final CalendarDate from = _nextTurnover(
      RotaEngine.forFamily(family),
      today,
    );

    return Family(
      id: family.id,
      name: family.name,
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
