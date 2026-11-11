import 'cycle.dart';
import 'member.dart';
import 'skipped_turn.dart';
import 'song.dart';

/// Everything the rota needs to answer a question, in one value.
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
  static const int currentSchemaVersion = 4;

  final String id;
  final String name;

  final List<Member> members;
  final List<Cycle> cycles;
  final List<SkippedTurn> skips;

  /// The songs this family loves (#110).
  final List<Song> songs;

  final int schemaVersion;

  Map<String, Member> get membersById => <String, Member>{
    for (final Member member in members) member.id: member,
  };

  /// The day the week currently turns over on: 1 is Monday, 7 is Sunday.
  int get turnoverWeekday => latestCycle.turnoverWeekday;

  /// Every signed-in member's uid, for the security rules.
  List<String> get memberUids => <String>[
    for (final Member member in members)
      if (member.uid case final String uid) uid,
  ];

  /// The newest epoch, by date and then by id.
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
