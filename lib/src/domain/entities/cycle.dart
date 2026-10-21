import 'calendar_date.dart';

/// Why a new cycle epoch was written.
enum CycleReason { initial, memberAdded, memberRemoved, reordered }

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
  /// Always a turnover day. [RotaEngine] enforces that, because the check
  /// needs the family's turnover weekday and a cycle does not carry one.
  final CalendarDate effectiveFrom;

  /// Member ids, in the order they take their turns.
  final List<String> order;

  final CycleReason reason;

  @override
  String toString() =>
      'Cycle($id, from $effectiveFrom, ${order.length} members)';
}
