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
    this.note,
  });

  final String id;

  /// The turnover day of the week being skipped.
  final CalendarDate weekStart;

  /// The member who would otherwise have led that week.
  final String memberId;

  final String? note;

  @override
  String toString() => 'SkippedTurn($memberId, week of $weekStart)';
}
