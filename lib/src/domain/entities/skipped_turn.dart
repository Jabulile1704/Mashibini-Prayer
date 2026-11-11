import 'calendar_date.dart';

/// A turn that was deliberately passed over.
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
