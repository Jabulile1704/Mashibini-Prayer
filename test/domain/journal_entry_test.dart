import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/serialization/journal_json.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/journal_entry.dart';

void main() {
  final CalendarDate day = CalendarDate(2026, 10, 28);
  final DateTime noon = DateTime.utc(2026, 10, 28, 12);

  JournalEntry entry({String text = 'Something'}) =>
      JournalEntry(id: 'j1', date: day, text: text, updatedAt: noon);

  group('JournalEntry', () {
    test('knows the month it belongs to, zero padded', () {
      expect(entry().month, '2026-10');
      expect(
        JournalEntry(
          id: 'j2',
          date: CalendarDate(2026, 3, 9),
          text: 'x',
          updatedAt: noon,
        ).month,
        '2026-03',
      );
    });

    test('months sort as strings, which is why they are padded', () {
      final List<String> months = <String>[
        JournalEntry(
          id: 'a',
          date: CalendarDate(2026, 12, 1),
          text: 'x',
          updatedAt: noon,
        ).month,
        JournalEntry(
          id: 'b',
          date: CalendarDate(2026, 3, 1),
          text: 'x',
          updatedAt: noon,
        ).month,
      ]..sort();
      expect(months, <String>['2026-03', '2026-12']);
    });

    test('copyWith changes the text and keeps the identity', () {
      final JournalEntry edited = entry().copyWith(
        text: 'Changed',
        updatedAt: noon.add(const Duration(hours: 1)),
      );

      expect(edited.id, 'j1');
      expect(edited.date, day);
      expect(edited.text, 'Changed');
      expect(edited.updatedAt.isAfter(noon), isTrue);
    });

    test('copyWith with nothing given changes nothing', () {
      expect(entry().copyWith(), entry());
    });

    test('is equal by all of its parts', () {
      expect(entry(), entry());
      expect(entry().hashCode, entry().hashCode);
      expect(entry() == entry(text: 'Different'), isFalse);
    });

    test('describes itself without spilling what was written', () {
      // A journal entry's text is the one thing that should not turn up in a
      // log line or a test failure message.
      final String described = entry(text: 'Something private').toString();

      expect(described, contains('j1'));
      expect(described, contains('2026-10-28'));
      expect(described, isNot(contains('private')));
    });
  });

  group('JournalJson', () {
    test('round trips an entry', () {
      final JournalEntry restored = JournalJson.decode(
        JournalJson.encode(entry()),
      );

      expect(restored, entry());
    });

    test('writes the date as a calendar date and the time as an instant', () {
      final String encoded = JournalJson.encode(entry());

      expect(encoded, contains('"date":"2026-10-28"'));
      expect(encoded, contains('2026-10-28T12:00:00.000Z'));
    });

    test('refuses something that is not an object', () {
      expect(() => JournalJson.decode('[]'), throwsFormatException);
      expect(() => JournalJson.decode('not json'), throwsFormatException);
    });

    test('a missing field names itself', () {
      expect(
        () => JournalJson.fromMap(<String, Object?>{'id': 'j1'}),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('date'),
          ),
        ),
      );
    });
  });
}
