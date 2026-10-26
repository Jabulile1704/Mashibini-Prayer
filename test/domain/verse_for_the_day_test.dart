import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/verse.dart';
import 'package:mashibini_prayer/src/domain/verse/verse_for_the_day.dart';

void main() {
  const Translation translation = Translation(
    name: 'Test Translation',
    abbreviation: 'TT',
    licence: 'Public Domain',
    notice: 'For testing.',
  );

  VerseForTheDay withVerses(int n) => VerseForTheDay(
    translation: translation,
    verses: <Verse>[
      for (int i = 0; i < n; i++)
        Verse(reference: 'Ref $i', text: 'Verse number $i'),
    ],
  );

  final CalendarDate someDay = CalendarDate(2026, 10, 27);

  group('the same verse for everybody (R3.1)', () {
    test('the same date gives the same verse, every time', () {
      final VerseForTheDay verses = withVerses(75);

      expect(verses.on(someDay), verses.on(someDay));
      expect(verses.on(someDay), withVerses(75).on(someDay));
    });

    test('two phones with the same date agree, having never spoken', () {
      // Separate instances stand in for separate devices: nothing is shared
      // between them but the date.
      final VerseForTheDay phoneA = withVerses(75);
      final VerseForTheDay phoneB = withVerses(75);

      for (int day = 0; day < 400; day++) {
        final CalendarDate date = someDay.addDays(day);
        expect(
          phoneA.on(date),
          phoneB.on(date),
          reason: 'day $day ($date) differs between devices',
        );
      }
    });

    test('a phone that was off for a month needs no catching up', () {
      final VerseForTheDay verses = withVerses(75);

      // Exactly the verse for that date, with nothing advanced in between.
      final CalendarDate later = someDay.addDays(31);
      expect(verses.on(later), verses.on(later));
      expect(verses.on(later), isNot(verses.on(someDay)));
    });
  });

  group('how it walks the set', () {
    test('consecutive days give consecutive verses', () {
      final VerseForTheDay verses = withVerses(10);

      final List<String> week = <String>[
        for (int i = 0; i < 10; i++) verses.on(someDay.addDays(i)).reference,
      ];

      expect(week.toSet(), hasLength(10), reason: 'no repeats within a cycle');
    });

    test('it comes round again after the whole set', () {
      final VerseForTheDay verses = withVerses(10);

      expect(verses.on(someDay.addDays(10)), verses.on(someDay));
      expect(verses.daysUntilRepeat, 10);
    });

    test('every verse is used, none is stranded', () {
      final VerseForTheDay verses = withVerses(75);
      final Set<String> seen = <String>{
        for (int i = 0; i < 75; i++) verses.on(someDay.addDays(i)).reference,
      };

      expect(seen, hasLength(75));
    });

    test('a single verse is allowed, and is always the answer', () {
      final VerseForTheDay verses = withVerses(1);

      expect(verses.on(someDay).reference, 'Ref 0');
      expect(verses.on(someDay.addDays(9)).reference, 'Ref 0');
    });
  });

  group('dates at the edges', () {
    test('dates before 1970 do not produce a negative index', () {
      final VerseForTheDay verses = withVerses(75);

      // Dart's % is non-negative for a positive divisor, but this is the one
      // place that would crash the home screen if it were not.
      expect(() => verses.on(CalendarDate(1900, 1, 1)), returnsNormally);
      expect(() => verses.on(CalendarDate(1969, 12, 31)), returnsNormally);
    });

    test('a date far in the future still resolves', () {
      expect(
        () => withVerses(75).on(CalendarDate(2199, 12, 31)),
        returnsNormally,
      );
    });

    test('ten years of days all resolve', () {
      final VerseForTheDay verses = withVerses(75);
      for (int i = 0; i < 3650; i++) {
        expect(verses.on(someDay.addDays(i)), isNotNull);
      }
    });
  });

  group('what it refuses', () {
    test('no verses at all', () {
      expect(
        () => VerseForTheDay(translation: translation, verses: const <Verse>[]),
        throwsArgumentError,
      );
    });
  });

  group('Verse', () {
    test('is equal by reference and text', () {
      expect(
        const Verse(reference: 'John 3:16', text: 'For God so loved…'),
        const Verse(reference: 'John 3:16', text: 'For God so loved…'),
      );
      expect(
        const Verse(reference: 'John 3:16', text: 'a').hashCode,
        const Verse(reference: 'John 3:16', text: 'a').hashCode,
      );
      expect(
        const Verse(reference: 'John 3:16', text: 'a') ==
            const Verse(reference: 'John 3:17', text: 'a'),
        isFalse,
      );
    });

    test('describes itself by its reference', () {
      expect(
        const Verse(reference: 'Psalm 23:1', text: 'x').toString(),
        'Verse(Psalm 23:1)',
      );
    });
  });
}
