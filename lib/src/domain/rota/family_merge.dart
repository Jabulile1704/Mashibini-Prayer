import '../entities/cycle.dart';
import '../entities/family.dart';
import '../entities/member.dart';
import '../entities/skipped_turn.dart';
import '../entities/song.dart';

/// Reconciles two versions of the same family (R6.2).
abstract final class FamilyMerge {
  /// Merges [a] and [b] into the family both devices should agree on.
  static Family merge(Family a, Family b) {
    if (a.id != b.id) {
      throw ArgumentError(
        'Cannot merge two different families: ${a.id} and ${b.id}',
      );
    }

    final Family newer = _newerOf(a, b);

    return Family(
      id: a.id,
      name: newer.name,
      members: _unionBy<Member>(
        a.members,
        b.members,
        id: (Member m) => m.id,
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
        resolve: (SkippedTurn x, SkippedTurn y) => x.withdrawn ? x : y,
        order: (SkippedTurn x, SkippedTurn y) {
          final int byDate = x.weekStart.compareTo(y.weekStart);
          return byDate != 0 ? byDate : x.id.compareTo(y.id);
        },
      ),
      songs: _unionBy<Song>(
        a.songs,
        b.songs,
        id: (Song s) => s.id,
        preferFirst: identical(newer, a),
        resolve: (Song x, Song y) => x.removed ? x : y,
        order: (Song x, Song y) {
          final int byDate = x.addedOn.compareTo(y.addedOn);
          return byDate != 0 ? byDate : x.id.compareTo(y.id);
        },
      ),
      schemaVersion: a.schemaVersion > b.schemaVersion
          ? a.schemaVersion
          : b.schemaVersion,
    );
  }

  /// Which family's scalars win.
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
  static List<T> _unionBy<T>(
    List<T> first,
    List<T> second, {
    required String Function(T) id,
    required bool preferFirst,
    required int Function(T, T) order,
    T Function(T existing, T incoming)? resolve,
  }) {
    final Map<String, T> byId = <String, T>{};
    // Whichever side is preferred is applied last, so it overwrites.
    for (final T item
        in preferFirst ? <T>[...second, ...first] : <T>[...first, ...second]) {
      final T? existing = byId[id(item)];
      byId[id(item)] = existing == null || resolve == null
          ? item
          : resolve(existing, item);
    }

    return byId.values.toList()..sort(order);
  }
}
