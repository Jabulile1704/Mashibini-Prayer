import '../entities/member.dart';

/// The family arranged in generations (#109).
///
/// Pure, like the rota: it takes members and returns rows. No widget, no
/// layout, no canvas — the drawing is the screen's problem and the shape is
/// this one's, which is what makes every awkward family testable without a
/// phone.
///
/// **A family is not reliably a tree.** Remarriages, a grandparent raising a
/// grandchild, a parent recorded after their own child — all of them produce
/// a shape a tidy recursive type would refuse. So the model is a set of
/// edges, and this turns edges into rows by depth:
///
/// ```text
/// depth(person) = 0                           if no parent is in the family
///               = 1 + max(depth of parents)   otherwise
/// ```
///
/// Taking the **maximum** rather than the minimum matters: a child of a
/// grandparent and a parent is drawn below the parent, not beside them.
abstract final class FamilyTree {
  /// Members by generation, eldest first.
  ///
  /// Everybody appears exactly once. Order within a row follows the order
  /// the members were given, which is the rota's order for anybody in it —
  /// so the top row of a family that has not recorded any relationships is
  /// simply the rota, which is what the screen showed before this existed.
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
  ///
  /// [visiting] is the chain currently being resolved, and is what stops a
  /// loop. Two people recorded as each other's parent is not something a
  /// screen should allow — [wouldMakeALoop] refuses it — but a family can
  /// arrive from a merge with another phone, and a stack overflow is a poor
  /// way to find that out. A member caught in a loop is treated as a root.
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
        // A parent the family has no record of is not a parent for drawing
        // purposes. The order is denormalised and can drift, exactly as
        // `cycle.order` can (RotaEngine.unresolvedMemberIds).
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
  ///
  /// Somebody cannot be their own ancestor. The screen asks this before it
  /// offers a name, so the refusal is an absence rather than an error
  /// message — a list of possible parents that cannot contain a wrong
  /// answer is kinder than one that does and complains afterwards.
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

    // Walk up from the proposed parent. If the child is already above it,
    // the edge would point backwards into its own ancestry.
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
