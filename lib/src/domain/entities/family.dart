import 'cycle.dart';
import 'member.dart';
import 'skipped_turn.dart';

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
    required this.turnoverWeekday,
    required this.members,
    required this.cycles,
    this.skips = const <SkippedTurn>[],
    this.schemaVersion = currentSchemaVersion,
  });

  /// The shape this version of the app writes.
  ///
  /// A change that an older build could not read increments this, and the
  /// migration becomes a documented, tested step rather than a crash report.
  static const int currentSchemaVersion = 1;

  final String id;
  final String name;

  /// ISO weekday the rota hands over on: 1 is Monday, 7 is Sunday.
  final int turnoverWeekday;

  final List<Member> members;
  final List<Cycle> cycles;
  final List<SkippedTurn> skips;
  final int schemaVersion;

  Map<String, Member> get membersById => <String, Member>{
    for (final Member member in members) member.id: member,
  };

  Family copyWith({
    String? name,
    int? turnoverWeekday,
    List<Member>? members,
    List<Cycle>? cycles,
    List<SkippedTurn>? skips,
  }) => Family(
    id: id,
    name: name ?? this.name,
    turnoverWeekday: turnoverWeekday ?? this.turnoverWeekday,
    members: members ?? this.members,
    cycles: cycles ?? this.cycles,
    skips: skips ?? this.skips,
    schemaVersion: schemaVersion,
  );

  @override
  String toString() =>
      'Family($id, $name, ${members.length} members, '
      '${cycles.length} cycles, ${skips.length} skips)';
}
