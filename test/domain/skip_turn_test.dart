import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/skipped_turn.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';

import '../support/fake_id_generator.dart';
import '../support/family_fixtures.dart';

void main() {
  /// Leader names for [count] weeks from [from].
  List<String> leaders(Family family, CalendarDate from, int count) {
    final RotaEngine engine = RotaEngine.forFamily(family);
    return <String>[
      for (int w = 0; w < count; w++)
        engine.turnOn(from.addDays(w * 7))?.leader.displayName ?? '-',
    ];
  }

  Family skip(
    Family family,
    CalendarDate weekStart, {
    CalendarDate? today,
    FakeIdGenerator? ids,
  }) => FamilyEditor.skipTurn(
    family,
    weekStart: weekStart,
    today: today ?? anchor,
    ids: ids ?? FakeIdGenerator(),
  );

  group('skipping a turn (R1.4)', () {
    test('the next member leads that week instead', () {
      // Sisi leads week two; skip it and Mama takes it.
      final Family after = skip(familyOfFour(), anchor.addDays(7));

      expect(leaders(after, anchor.addDays(7), 1).single, 'Mama');
    });

    test('the order is otherwise unchanged', () {
      final Family after = skip(familyOfFour(), anchor.addDays(7));

      expect(leaders(after, anchor, 6), <String>[
        'Jabulile',
        'Mama', // Sisi's week, skipped
        'Tata',
        'Jabulile',
        'Sisi',
        'Mama',
      ]);
    });

    test('the skipped member is not owed a double turn', () {
      // Sisi loses week two. When the cycle comes round, Sisi leads once —
      // in week five — not twice. A skip is forgiveness, not debt.
      final Family after = skip(familyOfFour(), anchor.addDays(7));
      final List<String> year = leaders(after, anchor, 12);

      expect(year.where((String name) => name == 'Sisi'), hasLength(2));
      expect(year.indexOf('Sisi'), 4);
    });

    test('weeks before the skip are untouched', () {
      final Family before = familyOfFour();
      final Family after = skip(
        before,
        anchor.addDays(21),
        today: anchor.addDays(14),
      );

      expect(leaders(after, anchor, 3), leaders(before, anchor, 3));
    });

    test('the record names who lost the turn, not who gained it', () {
      final Family after = skip(familyOfFour(), anchor.addDays(7));

      // Needed to tell somebody *whose* week was skipped once it no longer
      // shows in the rota. Recording the replacement instead would lose the
      // only fact the skip is about.
      expect(after.skips.single.memberId, sisi.id);
      expect(after.skips.single.weekStart, anchor.addDays(7));
    });

    test('a second skip passes over whoever holds that week by then', () {
      // The subtle one. Skipping week two hands it to Mama and pushes
      // everyone after along, so week three now belongs to **Tata** — not
      // Mama, who it belonged to before the first skip. Skipping week three
      // therefore passes over Tata.
      //
      // Getting this wrong is invisible in the rota and only shows up in the
      // record, which is why the ids are asserted as well as the names.
      Family family = familyOfFour();
      final FakeIdGenerator ids = FakeIdGenerator();
      family = skip(family, anchor.addDays(7), ids: ids);
      expect(leaders(family, anchor.addDays(14), 1).single, 'Tata');

      family = skip(family, anchor.addDays(14), ids: ids);

      expect(leaders(family, anchor, 5), <String>[
        'Jabulile',
        'Mama', // Sisi passed over
        'Jabulile', // Tata passed over
        'Sisi',
        'Mama',
      ]);
      expect(family.skips.map((SkippedTurn s) => s.memberId), <String>[
        sisi.id,
        tata.id,
      ], reason: 'each record names the person who actually lost that week');
    });
  });

  group('what cannot be skipped', () {
    test('a week that has already started', () {
      // Standing on the Wednesday of Jabulile's week.
      expect(
        () => skip(familyOfFour(), anchor, today: anchor.addDays(3)),
        throwsArgumentError,
      );
    });

    test('a week that has finished', () {
      expect(
        () => skip(familyOfFour(), anchor, today: anchor.addDays(21)),
        throwsArgumentError,
      );
    });

    test('the week in progress is refused on its own turnover day too', () {
      // The boundary: today *is* the turnover. The week has begun.
      expect(() => skip(familyOfFour(), anchor), throwsArgumentError);
    });

    test('a date that is not a turnover day', () {
      expect(
        () => skip(familyOfFour(), anchor.addDays(10)),
        throwsArgumentError,
      );
    });

    test('a week the rota does not run', () {
      // Before the cycle begins there is no turn to pass over.
      final Family notYet = familyOfFour();
      expect(
        () => FamilyEditor.skipTurn(
          notYet,
          weekStart: anchor.subtractDays(14),
          today: anchor.subtractDays(21),
          ids: FakeIdGenerator(),
        ),
        throwsArgumentError,
      );
    });

    test('a week that is already skipped', () {
      final Family once = skip(familyOfFour(), anchor.addDays(7));

      expect(() => skip(once, anchor.addDays(7)), throwsArgumentError);
    });
  });

  group('taking a skip back', () {
    test('the original leader has their week again', () {
      final Family skipped = skip(familyOfFour(), anchor.addDays(7));
      final Family restored = FamilyEditor.unskipTurn(
        skipped,
        weekStart: anchor.addDays(7),
      );

      expect(leaders(restored, anchor, 4), leaders(familyOfFour(), anchor, 4));
    });

    test('the record stays, marked withdrawn, rather than disappearing', () {
      // It has to survive: two phones merge skips by union, so a deleted
      // record would simply come back from the other device.
      final Family restored = FamilyEditor.unskipTurn(
        skip(familyOfFour(), anchor.addDays(7)),
        weekStart: anchor.addDays(7),
      );

      expect(restored.skips, hasLength(1));
      expect(restored.skips.single.withdrawn, isTrue);
    });

    test('a withdrawn skip is not a skip any more', () {
      final Family restored = FamilyEditor.unskipTurn(
        skip(familyOfFour(), anchor.addDays(7)),
        weekStart: anchor.addDays(7),
      );

      expect(FamilyEditor.skipOn(restored, anchor.addDays(7)), isNull);
    });

    test('the same week can be skipped again, as a new record', () {
      final FakeIdGenerator ids = FakeIdGenerator();
      final Family restored = FamilyEditor.unskipTurn(
        skip(familyOfFour(), anchor.addDays(7), ids: ids),
        weekStart: anchor.addDays(7),
      );
      final Family again = skip(restored, anchor.addDays(7), ids: ids);

      expect(again.skips, hasLength(2));
      expect(leaders(again, anchor.addDays(7), 1).single, 'Mama');
      // Two records, two ids: the withdrawn one is never revived, which is
      // what keeps `withdrawn` one-way and the merge safe.
      expect(again.skips.map((SkippedTurn s) => s.id).toSet(), hasLength(2));
    });

    test('a week that is not skipped cannot be unskipped', () {
      expect(
        () => FamilyEditor.unskipTurn(
          familyOfFour(),
          weekStart: anchor.addDays(7),
        ),
        throwsArgumentError,
      );
    });

    test('unskipping twice is refused rather than silently repeated', () {
      final Family restored = FamilyEditor.unskipTurn(
        skip(familyOfFour(), anchor.addDays(7)),
        weekStart: anchor.addDays(7),
      );

      expect(
        () => FamilyEditor.unskipTurn(restored, weekStart: anchor.addDays(7)),
        throwsArgumentError,
      );
    });
  });

  group('skips and the family changing underneath them', () {
    test('a skip survives somebody being added', () {
      final FakeIdGenerator ids = FakeIdGenerator();
      final Family skipped = skip(familyOfFour(), anchor.addDays(7), ids: ids);
      final Family after = FamilyEditor.addMember(
        skipped,
        displayName: 'Cousin',
        today: anchor.addDays(14),
        ids: ids,
      );

      expect(after.skips, hasLength(1));
      // The skipped week is behind the new epoch, so it still reads as it did.
      expect(leaders(after, anchor.addDays(7), 1).single, 'Mama');
    });

    test('who is in the rota is unaffected by a skip', () {
      final Family skipped = skip(familyOfFour(), anchor.addDays(7));

      expect(
        FamilyEditor.activeMembers(skipped, anchor).map((Member m) => m.id),
        <String>['m1', 'm2', 'm3', 'm4'],
        reason: 'a skip passes over a turn; it does not remove anybody',
      );
    });
  });
}
