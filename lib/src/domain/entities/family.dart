import 'cycle.dart';
import 'member.dart';
import 'skipped_turn.dart';
import 'song.dart';

/// Everything the rota needs to answer a question, in one value.
///
/// This is the aggregate the app loads on open and hands to [RotaEngine]. It
/// is deliberately a plain value: no identity beyond [id], no methods that
/// reach for data, nothing that knows where it was stored.
///
/// The rota of a family is small — four people, a handful of cycle epochs, a
/// few skips a year — so loading all of it at once is simpler than paging,
/// and makes the whole computation local (ADR-003).
class Family {
  Family({
    required this.id,
    required this.name,
    required this.members,
    required this.cycles,
    this.skips = const <SkippedTurn>[],
    this.songs = const <Song>[],
    this.schemaVersion = currentSchemaVersion,
  });

  /// The shape this version of the app writes.
  ///
  /// A change that an older build could not read increments this, and the
  /// migration becomes a documented, tested step rather than a crash report.
  ///
  /// **4** — the family has a songbook (#110). Additive and append-only,
  /// like the skips: absent means a family that has not added one.
  ///
  /// **3** — a member may carry a role, a photograph and their parents
  /// (#109). Purely additive: every field is optional and absent means what
  /// it meant before, so a v2 document reads as a family with no
  /// relationships recorded — which is exactly what it is.
  ///
  /// The version moved anyway. A v2 build reading a v3 family would drop
  /// the tree silently on the next save, and silently losing the thing
  /// somebody has just sat down and entered is worse than refusing to open
  /// the document.
  ///
  /// **2** — the turnover day belongs to the cycle, not the family (#100).
  /// Nothing was added to the document and nothing was removed from it; what
  /// changed is that two cycles may now sit on different weekdays. A v1 build
  /// would read such a family, hand it to `RotaEngine`, and throw on every
  /// frame of the home screen. The version is what makes it refuse instead.
  static const int currentSchemaVersion = 4;

  final String id;
  final String name;

  final List<Member> members;
  final List<Cycle> cycles;
  final List<SkippedTurn> skips;

  /// The songs this family loves (#110).
  ///
  /// On the family rather than beside the journal, because a songbook is
  /// shared and a journal is not (R4.2). That one placement decision is the
  /// difference between a thing the family keeps together and a thing each
  /// person keeps alone.
  final List<Song> songs;

  final int schemaVersion;

  Map<String, Member> get membersById => <String, Member>{
    for (final Member member in members) member.id: member,
  };

  /// The day the week currently turns over on: 1 is Monday, 7 is Sunday.
  ///
  /// Derived from the latest epoch rather than stored, so there is no second
  /// copy to fall out of step with the cycles (ADR-019). "Latest" is by
  /// [Cycle.effectiveFrom], which means that between a family changing the
  /// day and that change taking effect, this is already the *new* day — the
  /// one a further change would be measured against, and the one Settings
  /// should name as what it is changing.
  ///
  /// A date needs [RotaEngine.turnoverWeekdayOn] instead, which answers for
  /// the epoch actually governing that date.
  int get turnoverWeekday => latestCycle.turnoverWeekday;

  /// The newest epoch, by date and then by id.
  ///
  /// The id tie-break matches `RotaEngine`'s, so two phones that each wrote
  /// an epoch effective from the same turnover while offline still agree on
  /// which one is latest (R6.2).
  Cycle get latestCycle {
    if (cycles.isEmpty) {
      throw StateError('A family has at least one cycle; this one has none');
    }
    Cycle latest = cycles.first;
    for (final Cycle cycle in cycles.skip(1)) {
      final int byDate = cycle.effectiveFrom.compareTo(latest.effectiveFrom);
      if (byDate > 0 || (byDate == 0 && cycle.id.compareTo(latest.id) > 0)) {
        latest = cycle;
      }
    }
    return latest;
  }

  Family copyWith({
    String? name,
    List<Member>? members,
    List<Cycle>? cycles,
    List<SkippedTurn>? skips,
    List<Song>? songs,
  }) => Family(
    id: id,
    name: name ?? this.name,
    members: members ?? this.members,
    cycles: cycles ?? this.cycles,
    skips: skips ?? this.skips,
    songs: songs ?? this.songs,
    schemaVersion: schemaVersion,
  );

  @override
  String toString() =>
      'Family($id, $name, ${members.length} members, '
      '${cycles.length} cycles, ${skips.length} skips)';
}
