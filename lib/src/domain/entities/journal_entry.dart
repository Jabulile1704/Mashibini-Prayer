import 'calendar_date.dart';

/// Something somebody prayed about, on a day.
///
/// Deliberately thin. A journal entry is a date and some words; everything
/// else — tags, moods, titles, who it is shared with — is a feature nobody
/// asked for, and each one is a thing to migrate later.
///
/// There is no author on this class **yet**. Which phone wrote an entry is
/// not a question that can be answered until Q3 is — whether each member
/// signs in as themselves, or the family shares one install. Until then
/// entries live on the device that wrote them, and the device is the author.
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
  ///
  /// R4.3 groups a look back by month, and doing it here keeps the grouping
  /// out of the widget that displays it.
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
