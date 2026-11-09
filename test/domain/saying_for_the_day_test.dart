import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/saying.dart';
import 'package:mashibini_prayer/src/domain/saying/saying_for_the_day.dart';

void main() {
  const SayingSource source = SayingSource(
    tradition: 'Test tradition',
    languages: <String>['Testish'],
    notice: 'For testing.',
    reviewed: false,
  );

  SayingForTheDay withSayings(int n) => SayingForTheDay(
    source: source,
    sayings: <Saying>[
      for (int i = 0; i < n; i++)
        Saying(
          text: 'Saying number $i',
          original: 'Original $i',
          language: 'Testish',
        ),
    ],
  );

  final CalendarDate someDay = CalendarDate(2026, 10, 27);

  group('the same saying for everybody (R3.1)', () {
    test('the same date gives the same saying, every time', () {
      final SayingForTheDay sayings = withSayings(30);

      expect(sayings.on(someDay), sayings.on(someDay));
      expect(sayings.on(someDay), withSayings(30).on(someDay));
    });

    test('two phones with the same date agree, having never spoken', () {
      // Separate instances stand in for separate devices: nothing is shared
      // between them but the date.
      final SayingForTheDay phoneA = withSayings(30);
      final SayingForTheDay phoneB = withSayings(30);

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
      final SayingForTheDay sayings = withSayings(30);

      // Exactly the saying for that date, with nothing advanced in between.
      final CalendarDate later = someDay.addDays(31);
      expect(sayings.on(later), sayings.on(later));
      expect(sayings.on(later), isNot(sayings.on(someDay)));
    });
  });

  group('how it walks the set', () {
    test('consecutive days give consecutive sayings', () {
      final SayingForTheDay sayings = withSayings(10);

      final List<String> run = <String>[
        for (int i = 0; i < 10; i++) sayings.on(someDay.addDays(i)).text,
      ];

      expect(run.toSet(), hasLength(10), reason: 'no repeats within a cycle');
    });

    test('it comes round again after the whole set', () {
      final SayingForTheDay sayings = withSayings(10);

      expect(sayings.on(someDay.addDays(10)), sayings.on(someDay));
      expect(sayings.daysUntilRepeat, 10);
    });

    test('every saying is used, none is stranded', () {
      final SayingForTheDay sayings = withSayings(30);
      final Set<String> seen = <String>{
        for (int i = 0; i < 30; i++) sayings.on(someDay.addDays(i)).text,
      };

      expect(seen, hasLength(30));
    });

    test('a single saying is allowed, and is always the answer', () {
      final SayingForTheDay sayings = withSayings(1);

      expect(sayings.on(someDay).text, 'Saying number 0');
      expect(sayings.on(someDay.addDays(9)).text, 'Saying number 0');
    });
  });

  group('dates at the edges', () {
    test('dates before 1970 do not produce a negative index', () {
      final SayingForTheDay sayings = withSayings(30);

      // Dart's % is non-negative for a positive divisor, but this is the one
      // place that would crash the home screen if it were not.
      expect(() => sayings.on(CalendarDate(1900, 1, 1)), returnsNormally);
      expect(() => sayings.on(CalendarDate(1969, 12, 31)), returnsNormally);
    });

    test('a date far in the future still resolves', () {
      expect(
        () => withSayings(30).on(CalendarDate(2199, 12, 31)),
        returnsNormally,
      );
    });

    test('ten years of days all resolve', () {
      final SayingForTheDay sayings = withSayings(30);
      for (int i = 0; i < 3650; i++) {
        expect(sayings.on(someDay.addDays(i)), isNotNull);
      }
    });
  });

  group('what it refuses', () {
    test('no sayings at all', () {
      expect(
        () => SayingForTheDay(source: source, sayings: const <Saying>[]),
        throwsArgumentError,
      );
    });
  });

  group('Saying', () {
    test('is equal by its words and its language', () {
      expect(
        const Saying(
          text: 'A person is a person through other people.',
          original: 'Umntu ngumntu ngabantu',
          language: 'isiXhosa',
        ),
        const Saying(
          text: 'A person is a person through other people.',
          original: 'Umntu ngumntu ngabantu',
          language: 'isiXhosa',
        ),
      );
      expect(
        const Saying(text: 'a', language: 'isiXhosa').hashCode,
        const Saying(text: 'a', language: 'isiXhosa').hashCode,
      );
    });

    test('the same wisdom in two languages is two sayings', () {
      // Deliberate, and the reason the shipped file can hold both. The
      // English gloss is the same; the saying is not, and the card leads
      // with the original.
      expect(
        const Saying(
              text: 'A person is a person through other people.',
              original: 'Umntu ngumntu ngabantu',
              language: 'isiXhosa',
            ) ==
            const Saying(
              text: 'A person is a person through other people.',
              original: 'Motho ke motho ka batho',
              language: 'Sesotho',
            ),
        isFalse,
      );
    });

    test('an English-only saying is a different thing from a glossed one', () {
      expect(
        const Saying(text: 'a', language: 'isiXhosa') ==
            const Saying(text: 'a', original: 'a', language: 'isiXhosa'),
        isFalse,
      );
    });

    test('describes itself by its own words where it has them', () {
      expect(
        const Saying(
          text: 'A person is a person through other people.',
          original: 'Umntu ngumntu ngabantu',
          language: 'isiXhosa',
        ).toString(),
        'Saying(Umntu ngumntu ngabantu, isiXhosa)',
      );
      expect(
        const Saying(
          text: 'Hands wash one another.',
          language: 'isiXhosa',
        ).toString(),
        'Saying(Hands wash one another., isiXhosa)',
      );
    });
  });
}
