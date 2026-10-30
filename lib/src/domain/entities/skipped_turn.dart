import 'calendar_date.dart';

/// A turn that was deliberately passed over.
///
/// Named `SkippedTurn` rather than `Skip` because `package:flutter_test`
/// exports a `Skip` of its own — the annotation that skips a test. A domain
/// type that collides with it would force every test file to remember a
/// `hide` clause, and this project has already been bitten twice by rules
/// that depend on remembering.
///
/// A skip moves the whole cycle forward by one rather than swapping two
/// people, so the member who was away simply loses that turn and is not owed a
/// double one later. R1.4 calls this forgiveness rather than debt.
class SkippedTurn {
  const SkippedTurn({
    required this.id,
    required this.weekStart,
    required this.memberId,
    this.withdrawn = false,
    this.note,
  });

  final String id;

  /// The turnover day of the week being skipped.
  final CalendarDate weekStart;

  /// The member who would otherwise have led that week.
  final String memberId;

  /// Whether this skip has been taken back.
  ///
  /// Withdrawing rather than deleting, because skips are an append-only log
  /// and two phones merge by union (ADR-008): a record removed on one device
  /// would simply come back from the other. A flag merges instead — and only
  /// ever in one direction, which is what makes the merge safe to run twice
  /// or in either order.
  ///
  /// It never goes back to false. Skipping the same week again appends a new
  /// record with a new id rather than reviving this one, so the one-way rule
  /// holds without costing anybody the ability to change their mind twice.
  final bool withdrawn;

  final String? note;

  SkippedTurn withdraw() => SkippedTurn(
    id: id,
    weekStart: weekStart,
    memberId: memberId,
    withdrawn: true,
    note: note,
  );

  @override
  String toString() =>
      'SkippedTurn($memberId, week of $weekStart'
      '${withdrawn ? ', withdrawn' : ''})';
}
