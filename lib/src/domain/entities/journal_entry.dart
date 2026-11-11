import 'calendar_date.dart';

/// Something somebody prayed about, on a day.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.date,
    required this.text,
    required this.updatedAt,
  });

  final String id;

  /// The day the entry is *about*, which is not always the day it was typed.
  final CalendarDate date;

  final String text;

  /// When it was last written. Used for ordering within a day and, later,
  /// for deciding which version of an edited entry wins a sync.
  final DateTime updatedAt;

  JournalEntry copyWith({String? text, DateTime? updatedAt}) => JournalEntry(
    id: id,
    date: date,
    text: text ?? this.text,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// The month this entry belongs to, as `yyyy-mm`.
  String get month => '${date.year}-${date.month.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is JournalEntry &&
      other.id == id &&
      other.date == date &&
      other.text == text &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, date, text, updatedAt);

  @override
  String toString() => 'JournalEntry($id, $date, ${text.length} chars)';
}
