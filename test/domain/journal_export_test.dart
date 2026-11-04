import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/journal_entry.dart';
import 'package:mashibini_prayer/src/domain/journal/journal_export.dart';

/// The document a person keeps so that a reinstall cannot take their journal
/// (#104).
///
/// Pure, so every rule about what it says is tested here rather than against
/// a share sheet somebody has to dismiss by hand.
void main() {
  /// Unambiguous and sortable, which is what a test wants. The app passes
  /// `DateLabels.full`, so the real file reads "Sunday 18 October 2026".
  String iso(CalendarDate date) => date.toString();

  JournalEntry entry(int day, String text) => JournalEntry(
    id: 'j$day',
    date: CalendarDate(2026, 10, day),
    text: text,
    updatedAt: DateTime(2026, 10, day, 21),
  );

  final CalendarDate savedOn = CalendarDate(2026, 11, 4);

  test('says what it is, and when it was taken', () {
    final String document = JournalExport.asText(
      <JournalEntry>[entry(18, 'A line.')],
      formatDate: iso,
      savedOn: savedOn,
    );

    expect(document, startsWith('Mashibini Prayer — my prayer journal'));
    expect(document, contains('Saved from this phone on 2026-11-04.'));
  });

  test('runs oldest first, unlike the screen', () {
    // The journal screen shows newest first, because that is what somebody
    // opening the app wants. A kept copy is read end to end.
    final String document = JournalExport.asText(
      <JournalEntry>[
        entry(20, 'Third.'),
        entry(18, 'First.'),
        entry(19, 'Second.'),
      ],
      formatDate: iso,
      savedOn: savedOn,
    );

    expect(document.indexOf('First.'), lessThan(document.indexOf('Second.')));
    expect(document.indexOf('Second.'), lessThan(document.indexOf('Third.')));
  });

  test('counts them and gives the span', () {
    final String document = JournalExport.asText(
      <JournalEntry>[entry(18, 'a'), entry(19, 'b'), entry(25, 'c')],
      formatDate: iso,
      savedOn: savedOn,
    );

    expect(document, contains('3 entries, from 2026-10-18 to 2026-10-25'));
  });

  test('a single entry is not "1 entries, from x to x"', () {
    final String document = JournalExport.asText(
      <JournalEntry>[entry(18, 'a')],
      formatDate: iso,
      savedOn: savedOn,
    );

    expect(document, contains('1 entry, on 2026-10-18'));
    expect(document, isNot(contains('entries')));
  });

  test('every entry is in it, under its own date', () {
    final String document = JournalExport.asText(
      <JournalEntry>[entry(18, 'Thanked God for rain.'), entry(19, 'Gogo.')],
      formatDate: iso,
      savedOn: savedOn,
    );

    expect(document, contains('2026-10-18'));
    expect(document, contains('Thanked God for rain.'));
    expect(document, contains('2026-10-19'));
    expect(document, contains('Gogo.'));
    expect(
      JournalExport.separator.allMatches(document).length,
      2,
      reason: 'one separator before each entry',
    );
  });

  test('words are kept exactly as they were typed', () {
    // An export that tidied somebody's writing would be a worse copy than
    // the original, which defeats the point of having one.
    const String written = 'Line one.\nLine two.\n\n   Indented, trailing.   ';

    final String document = JournalExport.asText(
      <JournalEntry>[
        JournalEntry(
          id: 'j1',
          date: CalendarDate(2026, 10, 18),
          text: written,
          updatedAt: DateTime(2026, 10, 18, 21),
        ),
      ],
      formatDate: iso,
      savedOn: savedOn,
    );

    expect(document, contains(written));
  });

  test('an empty journal is still a document', () {
    // Not an empty string. Somebody who exports before writing anything
    // should get a file that says so, rather than a share sheet holding
    // nothing.
    final String document = JournalExport.asText(
      const <JournalEntry>[],
      formatDate: iso,
      savedOn: savedOn,
    );

    expect(document, contains('Nothing written yet.'));
    expect(document, contains('Saved from this phone on 2026-11-04.'));
    expect(document.trim(), isNotEmpty);
  });

  test('the subject line is dated the same way the document is', () {
    // It read "My prayer journal — 2026-11-04" over a document saying
    // "Wednesday, 4 November 2026" — two voices for one date, in the one
    // line somebody sees before they open anything.
    expect(
      JournalExport.subject(iso(savedOn)),
      'My prayer journal — 2026-11-04',
    );
    expect(
      JournalExport.subject('Wednesday, 4 November 2026'),
      'My prayer journal — Wednesday, 4 November 2026',
    );
  });

  test('the entries it was given are not reordered underneath the caller', () {
    // `all()` hands back the repository's own list in a release build; this
    // sorts a copy.
    final List<JournalEntry> given = <JournalEntry>[
      entry(20, 'later'),
      entry(18, 'earlier'),
    ];

    JournalExport.asText(given, formatDate: iso, savedOn: savedOn);

    expect(given.first.text, 'later');
  });
}
