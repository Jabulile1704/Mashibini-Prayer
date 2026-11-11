import '../entities/calendar_date.dart';
import '../entities/journal_entry.dart';

/// Turns a journal into something that can leave the phone.
abstract final class JournalExport {
  /// The whole journal as a document, oldest entry first.
  static String asText(
    List<JournalEntry> entries, {
    required String Function(CalendarDate) formatDate,
    required CalendarDate savedOn,
  }) {
    final List<JournalEntry> ordered = <JournalEntry>[...entries]
      ..sort((JournalEntry a, JournalEntry b) => a.date.compareTo(b.date));

    final StringBuffer out = StringBuffer()
      ..writeln('Mashibini Prayer — my prayer journal')
      ..writeln();

    if (ordered.isEmpty) {
      out
        ..writeln('Nothing written yet.')
        ..writeln()
        ..writeln('Saved from this phone on ${formatDate(savedOn)}.');
      return out.toString();
    }

    out
      ..writeln(
        ordered.length == 1
            ? '1 entry, on ${formatDate(ordered.first.date)}'
            : '${ordered.length} entries, from '
                  '${formatDate(ordered.first.date)} to '
                  '${formatDate(ordered.last.date)}',
      )
      ..writeln('Saved from this phone on ${formatDate(savedOn)}.');

    for (final JournalEntry entry in ordered) {
      out
        ..writeln()
        ..writeln(separator)
        ..writeln()
        ..writeln(formatDate(entry.date))
        ..writeln()
        ..writeln(entry.text);
    }

    return out.toString();
  }

  /// What the subject line says when the document is shared.
  static String subject(String savedOn) => 'My prayer journal — $savedOn';

  /// Between entries. Long enough to find by eye, plain enough to survive
  /// being pasted into anything.
  static const String separator = '────────────────';
}
