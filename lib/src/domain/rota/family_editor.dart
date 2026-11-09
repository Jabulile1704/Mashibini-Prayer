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

  /// Moves the day the week turns over on (R1.2, #100).
  ///
  /// Like adding or removing somebody, this writes a **new epoch** rather
  /// than editing the family, and for the same reason: the turnover day is
  /// what slices the calendar into weeks, so changing it in place would
  /// re-slice every week the rota has ever had. A Sunday somebody led would
  /// move into somebody else's week, and the journal entry they wrote on it
  /// with them (ADR-019, R2.3).
  ///
  /// **The new epoch begins on the first [weekday] that is after both the
  /// current week and every epoch already written.** The calendar does not
  /// divide evenly, so that leaves the epoch before it a last week of one to
  /// six days instead of seven. There is no way to avoid a short interval —
  /// the only alternative is a gap with no leader at all — and a short week
  /// is the kind a family absorbs without noticing.
  ///
  /// Why "after every epoch already written" and not simply after this week:
  /// a family that changes the day twice before the first change has taken
  /// effect would otherwise have the second land *before* the first, where
  /// the engine would resolve the first one anyway and nothing would appear
  /// to happen. Epochs are appended, never replaced — a cycle deleted on one
  /// phone comes back from the other's copy (ADR-012) — so the second change
  /// takes effect after the first, and the family gets two short weeks.
  /// Changing twice in a week costs something; it just does not cost
  /// correctness.
  ///
  /// **The short week counts as a turn.** The new epoch's order begins with
  /// the person *after* whoever led the day before it starts, so nobody
  /// leads two weeks running. The other choice — carrying the short week's
  /// leader into the new epoch's first full week — would have given them up
  /// to thirteen days, which a family would notice.
  static Family changeTurnoverDay(
    Family family, {
    required int weekday,
    required CalendarDate today,
    required IdGenerator ids,
  }) {
    Week.assertValidWeekday(weekday);

    // Measured against the latest epoch, which is what `Settings` shows and
    // what a family asked to pick a day is choosing against. Not against
    // today's week: between a change and the day it takes effect those are
    // different answers, and rejecting "put it back to Sunday" because
    // Sunday is still in force this week would refuse a correction.
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

    // The rota carries on from whoever had the day before, whatever epoch
    // that day belonged to and however short its week turned out to be.
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

  /// Adds somebody to the **family** without putting them in the rota (#109).
  ///
  /// The distinction the tree exists for. `addMember` writes a new cycle and
  /// hands the person a week; this writes no cycle at all, so a grandchild,
  /// a grandparent or anybody else can appear in the tree without being
  /// handed a turn at leading prayer.
  ///
  /// No epoch means nothing to defer — they are in the family the moment it
  /// is saved, because there is no week boundary for a non-participant to
  /// wait for.
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
  ///
  /// For a role, a photograph, parents or a corrected spelling — none of
  /// which is a change to who takes a week, so none of them writes an
  /// epoch. A rename is a rename: the cycles reference ids, so the person
  /// who led in March keeps the turn and gains the new spelling, which is
  /// what somebody fixing a typo means.
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
  ///
  /// The start of next week, by that week's own reckoning. Exposed because a
  /// screen has to **say** this before it asks somebody to confirm anything:
  /// every edit here lands at the next turnover rather than now, and a
  /// confirmation that does not name the date is asking for agreement to
  /// something it has not described.
  ///
  /// A change of turnover day lands later than this — see
  /// [changeTurnoverDay], which has its own rule — so a screen offering that
  /// should build the change and read [Family.latestCycle] off it rather than
  /// asking here.
  static CalendarDate changesTakeEffect(Family family, CalendarDate today) =>
      _nextTurnover(RotaEngine.forFamily(family), today);

  /// Ties a signed-in account to one member of the family (#76, ADR-023).
  ///
  /// This is what makes `Family.memberUids` non-empty, and therefore what
  /// lets anything sync at all — every path in `firestore.rules` asks
  /// whether `request.auth.uid` is in that list.
  ///
  /// **A uid belongs to exactly one person.** Two members sharing one
  /// account would make "only the author may read this journal" (R4.2)
  /// unenforceable, because the database could not tell them apart. So
  /// linking an account that is already on somebody else is refused rather
  /// than quietly moved: it almost always means the wrong name was picked,
  /// and silently reassigning it would hand one person another's journal.
  ///
  /// Linking is idempotent — signing in twice on the same phone, which
  /// happens on every reinstall, must not be an error.
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
  ///
  /// Signing out on a phone does **not** call this: the account still
  /// belongs to that person, and unlinking would drop them out of
  /// `memberUids` and stop every other phone syncing their changes. This is
  /// for the other case — the wrong name was picked and has to be undone.
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
  ///
  /// Takes effect immediately. There is no epoch and no next turnover to
  /// wait for: a song is not a turn, and nothing about who leads prayer
  /// changes because somebody wrote down what they like.
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
  ///
  /// Marked rather than deleted (ADR-012). Two phones merge by union, so a
  /// record removed on one would come back from the other; a flag merges in
  /// one direction and survives.
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
  ///
  /// Removed records stay in `family.songs` because that is how two phones
  /// agree one was taken out; they are not in the book any more, so they do
  /// not answer here.
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
  ///
  /// The day after this week ends, rather than seven days after it started.
  /// The two differ by up to six days in the one week that follows a change
  /// of turnover day, and the day after is the one that is right in both
  /// cases (ADR-019).
  static CalendarDate _nextTurnover(RotaEngine engine, CalendarDate today) {
    final Turn? current = engine.turnOn(today);
    return current != null
        ? current.weekEnd.addDays(1)
        : engine.weekStartOn(today).addDays(7);
  }

  /// [order] rotated so that [first] leads it.
  ///
  /// Unchanged when [first] is null or not in the order — there is then
  /// nobody the next turn was promised to, so there is nothing to preserve.
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
