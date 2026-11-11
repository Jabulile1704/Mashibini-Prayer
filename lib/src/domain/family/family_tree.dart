import '../entities/member.dart';

/// The family arranged in generations (#109).
abstract final class FamilyTree {
  /// Members by generation, eldest first.
  static List<List<Member>> generations(List<Member> members) {
    final Map<String, Member> byId = <String, Member>{
      for (final Member member in members) member.id: member,
    };
    final Map<String, int> depths = <String, int>{};

    for (final Member member in members) {
      _depthOf(member.id, byId, depths, <String>{});
    }

    int deepest = 0;
    for (final int depth in depths.values) {
      if (depth > deepest) {
        deepest = depth;
      }
    }

    final List<List<Member>> rows = <List<Member>>[
      for (int i = 0; i <= deepest; i++) <Member>[],
    ];
    for (final Member member in members) {
      rows[depths[member.id] ?? 0].add(member);
    }
    return <List<Member>>[
      for (final List<Member> row in rows)
        if (row.isNotEmpty) row,
    ];
  }

  /// How far below the eldest generation this person sits.
  static int _depthOf(
    String id,
    Map<String, Member> byId,
    Map<String, int> depths,
    Set<String> visiting,
  ) {
    final int? known = depths[id];
    if (known != null) {
      return known;
    }
    if (!visiting.add(id)) {
      return 0;
    }

    int depth = 0;
    final Member? member = byId[id];
    if (member != null) {
      for (final String parentId in member.parentIds) {
        if (!byId.containsKey(parentId)) {
          continue;
        }
        final int above = _depthOf(parentId, byId, depths, visiting) + 1;
        if (above > depth) {
          depth = above;
        }
      }
    }

    visiting.remove(id);
    depths[id] = depth;
    return depth;
  }

  /// Whether making [parentId] a parent of [childId] would close a loop.
  static bool wouldMakeALoop(
    List<Member> members, {
    required String childId,
    required String parentId,
  }) {
    if (childId == parentId) {
      return true;
    }
    final Map<String, Member> byId = <String, Member>{
      for (final Member member in members) member.id: member,
    };

    final Set<String> seen = <String>{};
    final List<String> frontier = <String>[parentId];
    while (frontier.isNotEmpty) {
      final String at = frontier.removeLast();
      if (at == childId) {
        return true;
      }
      if (!seen.add(at)) {
        continue;
      }
      final Member? member = byId[at];
      if (member != null) {
        frontier.addAll(member.parentIds);
      }
    }
    return false;
  }

  /// Everyone who could be named a parent of [childId], in [members] order.
  static List<Member> possibleParentsFor(
    List<Member> members, {
    required String childId,
  }) => <Member>[
    for (final Member member in members)
      if (!wouldMakeALoop(members, childId: childId, parentId: member.id))
        member,
  ];
}
