import 'calendar_date.dart';

/// Why a new cycle epoch was written.
enum CycleReason {
  initial,
  memberAdded,
  memberRemoved,
  reordered,
  turnoverDayChanged,
}

/// One epoch of the rota: an order of members, in force from a date.
class Cycle {
  Cycle({
    required this.id,
    required this.effectiveFrom,
    required this.order,
    this.reason = CycleReason.initial,
  }) : assert(order.isNotEmpty, 'A cycle needs at least one member');

  final String id;

  /// The first day of the first week this cycle governs.
  final CalendarDate effectiveFrom;

  /// Member ids, in the order they take their turns.
  final List<String> order;

  final CycleReason reason;

  /// The day of the week this epoch hands the rota over on: 1 is Monday,
  /// 7 is Sunday.
  int get turnoverWeekday => effectiveFrom.weekday;

  @override
  String toString() =>
      'Cycle($id, from $effectiveFrom, ${order.length} members)';
}
