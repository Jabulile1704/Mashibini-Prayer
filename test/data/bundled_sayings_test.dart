import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/sources/assets/bundled_sayings.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/saying.dart';
import 'package:mashibini_prayer/src/domain/saying/saying_for_the_day.dart';

/// These read the **real** `assets/sayings.json` that ships with the app, not
/// a fixture. A fixture would prove the parser works on text we wrote; the
/// point here is that the file we actually ship is well-formed and attributed
/// — which is R3.2, and is the kind of thing that only ever breaks in
/// production.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(BundledSayings.forgetCache);

  Future<SayingForTheDay> loadShipped() =>
      BundledSayings.load(bundle: rootBundle);

  List<Saying> all(SayingForTheDay sayings) => <Saying>[
    for (int i = 0; i < sayings.count; i++)
      sayings.on(CalendarDate(1970, 1, 1).addDays(i)),
  ];

  group('the file that ships', () {
    test('parses, and holds a useful number of sayings', () async {
      final SayingForTheDay sayings = await loadShipped();

      // Twenty, not the sixty the verses had. A proverb is meant to come
      // round: a family that meets the same twenty over a month is being
      // taught them, which is what a proverb is for. The floor is here to
      // catch the file being emptied, not to chase a number.
      expect(sayings.count, greaterThanOrEqualTo(20));
      expect(sayings.daysUntilRepeat, sayings.count);
    });

    test('names the tradition and the languages it carries (R3.2)', () async {
      final SayingForTheDay sayings = await loadShipped();

      expect(sayings.source.tradition, 'Southern African');
      expect(sayings.source.languages, isNotEmpty);
      expect(sayings.source.notice, isNotEmpty);
    });

    test('every saying names a language the source claims', () async {
      final SayingForTheDay sayings = await loadShipped();

      for (final Saying saying in all(sayings)) {
        expect(
          sayings.source.languages,
          contains(saying.language),
          reason:
              '"${saying.original ?? saying.text}" is in ${saying.language}, '
              'which the source block does not list',
        );
      }
    });

    test('every saying carries some English', () async {
      final SayingForTheDay sayings = await loadShipped();

      for (final Saying saying in all(sayings)) {
        expect(saying.text.trim(), isNotEmpty);
        // The original is optional by design — see `Saying.original`. Where
        // one is given it must not be blank, which is the honest failure
        // mode: a key present and empty would render a gap on the card.
        expect(saying.original?.trim() ?? 'given', isNotEmpty);
      }
    });

    test('no saying is so long it cannot be read at a glance', () async {
      final SayingForTheDay sayings = await loadShipped();

      for (final Saying saying in all(sayings)) {
        expect(
          saying.text.length,
          lessThan(320),
          reason: '"${saying.text}" is ${saying.text.length} characters',
        );
      }
    });

    test('no two entries are the same saying in the same language', () async {
      final SayingForTheDay sayings = await loadShipped();

      // Keyed on the saying **and** its language, because the same wisdom
      // genuinely appears in several of them: `Umntu ngumntu ngabantu` and
      // `Motho ke motho ka batho` share an English gloss and are not
      // duplicates. The card leads with the original, so they do not read
      // as a repeat.
      final Set<String> keys = <String>{
        for (final Saying saying in all(sayings))
          '${saying.original ?? saying.text}|${saying.language}',
      };

      expect(keys, hasLength(sayings.count));
    });

    test('says whether a speaker has checked the wording', () async {
      final SayingForTheDay sayings = await loadShipped();

      // Not an assertion that it **is** reviewed — at the time of writing it
      // is not, and the flag is how the app says so rather than how it
      // hides it. This asserts the field survives the round trip, so that
      // flipping it to true is a one-line change that the About screen
      // picks up. Day 28 is where this is explained.
      expect(sayings.source.reviewed, isA<bool>());
    });

    test('is cached rather than re-read on every build', () async {
      final SayingForTheDay first = await loadShipped();
      final SayingForTheDay second = await loadShipped();

      expect(identical(first, second), isTrue);
    });
  });

  group('bad data is refused clearly', () {
    String document({
      Map<String, Object?>? source,
      List<Object?> sayings = const <Object?>[],
    }) => jsonEncode(<String, Object?>{
      'source':
          source ??
          <String, Object?>{
            'tradition': 'x',
            'languages': <String>['x'],
            'notice': 'x',
          },
      'sayings': sayings,
    });

    test('something that is not an object', () {
      expect(() => BundledSayings.parse('[]'), throwsFormatException);
      expect(() => BundledSayings.parse('"text"'), throwsFormatException);
    });

    test('a missing source block', () {
      expect(
        () => BundledSayings.parse(
          jsonEncode(<String, Object?>{'sayings': <Object?>[]}),
        ),
        throwsFormatException,
      );
    });

    test('a saying missing its language says which field', () {
      expect(
        () => BundledSayings.parse(
          document(
            sayings: <Object?>[
              <String, Object?>{'text': 'no language here'},
            ],
          ),
        ),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('language'),
          ),
        ),
      );
    });

    test('an empty list of sayings is refused', () {
      expect(() => BundledSayings.parse(document()), throwsArgumentError);
    });

    test('a missing review flag reads as not reviewed', () {
      // The direction matters. A file that forgets the field must not be
      // taken to have a speaker's approval nobody gave.
      final SayingForTheDay parsed = BundledSayings.parse(
        document(
          sayings: <Object?>[
            <String, Object?>{'text': 'Something true.', 'language': 'x'},
          ],
        ),
      );

      expect(parsed.source.reviewed, isFalse);
    });
  });
}
