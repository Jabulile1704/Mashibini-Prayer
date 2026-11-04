import '../entities/calendar_date.dart';
import '../entities/journal_entry.dart';

/// Turns a journal into something that can leave the phone.
///
/// The journal is the only thing in this app that cannot be reconstructed.
/// The rota can be retyped in under a minute; what somebody wrote during
/// their week cannot be. And a reinstall takes it — on iOS the build is
/// signed by a free Apple account whose certificate is reissued about every
/// seven days, so each new build is a different app as far as the phone is
/// concerned, and installing it uninstalls the old one and its container
/// (#104).
///
/// Nothing here shares anything. This produces a string; the platform's
/// share sheet is a data-layer concern, so every rule about *what the
/// document says* is tested without a plugin, a device, or a share sheet
/// that would have to be dismissed by hand.
///
/// Plain text on purpose. A format nobody has to own, that opens in
/// anything, that still reads in ten years — and that a person can check at
/// a glance, which matters for the one file whose job is to be trusted.
abstract final class JournalExport {
  /// The whole journal as a document, oldest entry first.
  ///
  /// **Oldest first**, unlike the journal screen, which shows newest first
  /// because that is what somebody opening the app wants. A kept copy is
  /// read end to end rather than dipped into, and a journal that runs
  /// forwards is the one everybody already knows how to read.
  ///
  /// [formatDate] comes from the caller because the domain cannot reach a
  /// locale (ADR-002's reasoning, applied to words rather than to clocks):
  /// the screen passes the same formatter the rest of the app uses, so the
  /// file says "Wednesday 4 November 2026" exactly as the app does.
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
      // An empty journal still produces a document rather than an empty
      // string. Somebody who exports before writing anything should get a
      // file that says so, not a share sheet with nothing in it.
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
        // Written out exactly as typed, line breaks and all. An export that
        // tidied somebody's words would be a worse copy than the original.
        ..writeln(entry.text);
    }

    return out.toString();
  }

  /// What the subject line says when the document is shared.
  ///
  /// Takes the date already written out, for the same reason [asText] takes
  /// a formatter: this is the line somebody sees in their mail, and it read
  /// "My prayer journal — 2026-11-04" over a document saying "Wednesday,
  /// 4 November 2026" — two voices for one date, in the one place where the
  /// app is speaking to somebody outside it.
  static String subject(String savedOn) => 'My prayer journal — $savedOn';

  /// Between entries. Long enough to find by eye, plain enough to survive
  /// being pasted into anything.
  static const String separator = '────────────────';
}
