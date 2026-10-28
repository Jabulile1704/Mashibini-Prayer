import 'dart:convert';

import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/journal_entry.dart';
import 'json_reads.dart';

/// Translates a journal entry to and from the JSON the device holds.
abstract final class JournalJson {
  static String encode(JournalEntry entry) => jsonEncode(toMap(entry));

  static JournalEntry decode(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('Expected a JSON object', source);
    }
    return fromMap(decoded);
  }

  static Map<String, Object?> toMap(JournalEntry entry) => <String, Object?>{
    'id': entry.id,
    'date': entry.date.toString(),
    'text': entry.text,
    // An instant, not a calendar date: this one really is a moment, and it
    // exists to order edits rather than to name a day.
    'updatedAt': entry.updatedAt.toUtc().toIso8601String(),
  };

  static JournalEntry fromMap(Map<String, Object?> json) => JournalEntry(
    id: readString(json, 'id'),
    date: CalendarDate.parse(readString(json, 'date')),
    text: readString(json, 'text'),
    updatedAt: DateTime.parse(readString(json, 'updatedAt')),
  );
}
