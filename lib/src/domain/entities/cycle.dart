import 'calendar_date.dart';

/// Why a new cycle epoch was written.
///
/// A label on a past decision, never something the rota computes with, which
/// is why a value this build does not know is read as [reordered] rather than
/// failing a load (`FamilyJson`).
enum CycleReason {
  initial,
  memberAdded,
  memberRemoved,
  reordered,
  turnoverDayChanged,
}

/// One epoch of the rota: an order of members, in force from a date.
///
/// A cycle is versioned rather than edited. If the family changes, a *new*
/// cycle is written with a later [effectiveFrom], and dates before it still
/// resolve against the old one. That is the only reason a past turn can keep
/// showing the person who actually led it (R2.3) while the leader for any date
/// stays a pure computation (ADR-002).
class Cycle {
  Cycle({
    required this.id,
    required this.effectiveFrom,
    required this.order,
    this.reason = CycleReason.initial,
  }) : assert(order.isNotEmpty, 'A cycle needs at least one member');

  final String id;

  /// The first day of the first week this cycle governs.
  ///
  /// Always a turnover day — see [turnoverWeekday], which is the same fact
  /// read the other way round.
  final CalendarDate effectiveFrom;

  /// Member ids, in the order they take their turns.
  final List<String> order;

  final CycleReason reason;

  /// The day of the week this epoch hands the rota over on: 1 is Monday,
  /// 7 is Sunday.
  ///
  /// Derived, not stored. A cycle's [effectiveFrom] is by definition the
  /// first day of one of its weeks, so its weekday *is* this epoch's
  /// turnover day; storing the two separately would only create a pair that
  /// can disagree. Which is what the engine used to guard against:
  ///
  /// ```dart
  /// if (cycle.effectiveFrom.weekday != turnoverWeekday) throw …
  /// ```
  ///
  /// That check is gone because the thing it checked cannot now be false
  /// (ADR-019, #100).
  int get turnoverWeekday => effectiveFrom.weekday;

  @override
  String toString() =>
      'Cycle($id, from $effectiveFrom, ${order.length} members)';
}
