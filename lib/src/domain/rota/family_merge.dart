import '../entities/cycle.dart';
import '../entities/family.dart';
import '../entities/member.dart';
import '../entities/skipped_turn.dart';

/// Reconciles two versions of the same family (R6.2).
///
/// Two phones can both change the rota while offline. When they reconnect,
/// something has to decide what the family now is, and the requirement asks
/// for two things that usually pull against each other: the result must be
/// **deterministic**, and the losing change must not be **silently discarded**.
///
/// Both fall out of the data model rather than from cleverness here. Members,
/// cycles and skips are all append-only logs keyed by id, so merging is a
/// union, and a union does not have a winner to discard. Where two edits
/// genuinely collide — two epochs effective from the same turnover — both
/// survive in the family, and the rota resolves to one of them by a rule that
/// does not depend on who synced first (see `RotaEngine`'s ordering).
///
/// Last-write-wins is used for exactly one thing: the family's own scalar
/// fields, where there is nothing to merge and no history to keep.
abstract final class FamilyMerge {
  /// Merges [a] and [b] into the family both devices should agree on.
  ///
  /// Commutative: `merge(a, b)` and `merge(b, a)` produce the same family.
  /// That property is the whole of "deterministic", and it is tested
  /// directly rather than assumed.
  static Family merge(Family a, Family b) {
    if (a.id != b.id) {
      throw ArgumentError(
        'Cannot merge two different families: ${a.id} and ${b.id}',
      );
    }

    final Family newer = _newerOf(a, b);

    return Family(
      id: a.id,
      // Scalars have no history to preserve, so the newer schema wins. Where
      // both are equal this is simply a's value, which is why _newerOf breaks
      // its own tie deterministically.
      name: newer.name,
      turnoverWeekday: newer.turnoverWeekday,
      members: _unionBy<Member>(
        a.members,
        b.members,
        id: (Member m) => m.id,
        // The two sides can only disagree on a rename, so the same side that
        // wins the scalars wins here, keeping the result coherent.
        preferFirst: identical(newer, a),
        order: (Member x, Member y) => x.id.compareTo(y.id),
      ),
      cycles: _unionBy<Cycle>(
        a.cycles,
        b.cycles,
        id: (Cycle c) => c.id,
        preferFirst: identical(newer, a),
        order: (Cycle x, Cycle y) {
          final int byDate = x.effectiveFrom.compareTo(y.effectiveFrom);
          return byDate != 0 ? byDate : x.id.compareTo(y.id);
        },
      ),
      skips: _unionBy<SkippedTurn>(
        a.skips,
        b.skips,
        id: (SkippedTurn s) => s.id,
        preferFirst: identical(newer, a),
        order: (SkippedTurn x, SkippedTurn y) {
          final int byDate = x.weekStart.compareTo(y.weekStart);
          return byDate != 0 ? byDate : x.id.compareTo(y.id);
        },
      ),
      schemaVersion: a.schemaVersion > b.schemaVersion
          ? a.schemaVersion
          : b.schemaVersion,
    );
  }

  /// Which family's scalars win.
  ///
  /// More cycles means more changes have been made, which is the closest
  /// thing to a clock this model has — and unlike a timestamp it cannot be
  /// wrong because somebody's phone has the wrong date. Ties break on the
  /// name, so the answer never depends on argument order.
  static Family _newerOf(Family a, Family b) {
    if (a.cycles.length != b.cycles.length) {
      return a.cycles.length > b.cycles.length ? a : b;
    }
    if (a.skips.length != b.skips.length) {
      return a.skips.length > b.skips.length ? a : b;
    }
    if (a.members.length != b.members.length) {
      return a.members.length > b.members.length ? a : b;
    }
    return a.name.compareTo(b.name) <= 0 ? a : b;
  }

  /// Everything from both sides, keyed by id, in a canonical order.
  ///
  /// Where both hold the same id, the preferred side's version is kept — the
  /// only way the two can differ for the same id is an edit, and an edit
  /// should not be lost to whichever argument came first.
  ///
  /// The result is sorted by [order] rather than left in arrival order. That
  /// is not tidiness: two phones merging the same pair in opposite orders
  /// would otherwise produce equivalent lists in different sequences, write
  /// those documents back, and each see the other's as a change — syncing at
  /// each other indefinitely over a difference that means nothing.
  static List<T> _unionBy<T>(
    List<T> first,
    List<T> second, {
    required String Function(T) id,
    required bool preferFirst,
    required int Function(T, T) order,
  }) {
    final Map<String, T> byId = <String, T>{};
    // Whichever side is preferred is applied last, so it overwrites.
    for (final T item
        in preferFirst ? <T>[...second, ...first] : <T>[...first, ...second]) {
      byId[id(item)] = item;
    }

    return byId.values.toList()..sort(order);
  }
}
