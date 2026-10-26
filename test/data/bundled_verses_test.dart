import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/sources/assets/bundled_verses.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/verse.dart';
import 'package:mashibini_prayer/src/domain/verse/verse_for_the_day.dart';

/// These read the **real** `assets/verses.json` that ships with the app, not
/// a fixture. A fixture would prove the parser works on text we wrote; the
/// point here is that the file we actually ship is well-formed, licensed and
/// attributed — which is R3.2, and is the kind of thing that only ever breaks
/// in production.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(BundledVerses.forgetCache);

  Future<VerseForTheDay> loadShipped() =>
      BundledVerses.load(bundle: rootBundle);

  group('the file that ships', () {
    test('parses, and holds a useful number of verses', () async {
      final VerseForTheDay verses = await loadShipped();

      expect(verses.count, greaterThanOrEqualTo(60));
      expect(verses.daysUntilRepeat, verses.count);
    });

    test(
      'names a translation whose licence permits redistribution (R3.2)',
      () async {
        final VerseForTheDay verses = await loadShipped();

        expect(verses.translation.name, contains('World English Bible'));
        expect(verses.translation.licence, 'Public Domain');
        expect(verses.translation.notice, isNotEmpty);
      },
    );

    test('every verse carries a reference and some text', () async {
      final VerseForTheDay verses = await loadShipped();

      for (int i = 0; i < verses.count; i++) {
        final Verse verse = verses.on(CalendarDate(1970, 1, 1).addDays(i));
        expect(verse.reference, isNotEmpty);
        expect(verse.text.trim(), isNotEmpty);
        expect(
          verse.reference,
          matches(RegExp(r'^[1-3]? ?[A-Za-z]+ \d+:\d+$')),
          reason: '"${verse.reference}" is not a citable reference',
        );
      }
    });

    test('no verse is so long it cannot be read at a glance', () async {
      final VerseForTheDay verses = await loadShipped();

      for (int i = 0; i < verses.count; i++) {
        final Verse verse = verses.on(CalendarDate(1970, 1, 1).addDays(i));
        expect(
          verse.text.length,
          lessThan(320),
          reason: '${verse.reference} is ${verse.text.length} characters',
        );
      }
    });

    test('no two entries are the same verse', () async {
      final VerseForTheDay verses = await loadShipped();
      final Set<String> references = <String>{
        for (int i = 0; i < verses.count; i++)
          verses.on(CalendarDate(1970, 1, 1).addDays(i)).reference,
      };

      expect(references, hasLength(verses.count));
    });

    test('is cached rather than re-read on every build', () async {
      final VerseForTheDay first = await loadShipped();
      final VerseForTheDay second = await loadShipped();

      expect(identical(first, second), isTrue);
    });
  });

  group('bad data is refused clearly', () {
    test('something that is not an object', () {
      expect(() => BundledVerses.parse('[]'), throwsFormatException);
      expect(() => BundledVerses.parse('"text"'), throwsFormatException);
    });

    test('a missing translation block', () {
      expect(
        () => BundledVerses.parse(
          jsonEncode(<String, Object?>{'verses': <Object?>[]}),
        ),
        throwsFormatException,
      );
    });

    test('a verse missing its reference says which field', () {
      expect(
        () => BundledVerses.parse(
          jsonEncode(<String, Object?>{
            'translation': <String, Object?>{
              'name': 'x',
              'abbreviation': 'x',
              'licence': 'x',
              'notice': 'x',
            },
            'verses': <Object?>[
              <String, Object?>{'text': 'no reference here'},
            ],
          }),
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('reference'),
          ),
        ),
      );
    });

    test('an empty verse list is refused', () {
      expect(
        () => BundledVerses.parse(
          jsonEncode(<String, Object?>{
            'translation': <String, Object?>{
              'name': 'x',
              'abbreviation': 'x',
              'licence': 'x',
              'notice': 'x',
            },
            'verses': <Object?>[],
          }),
        ),
        throwsArgumentError,
      );
    });
  });
}
