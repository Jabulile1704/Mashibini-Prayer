import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/skipped_turn.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';
import 'package:mashibini_prayer/src/domain/rota/family_merge.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';

import '../support/fake_id_generator.dart';
import '../support/family_fixtures.dart';

/// R6.2 asks for two things that usually pull against each other: the result
/// must be deterministic, and the losing change must not be silently
/// discarded. These tests check both as properties rather than as examples.
void main() {
  List<String> leaders(Family family, CalendarDate from, int count) {
    final RotaEngine engine = RotaEngine.forFamily(family);
    return <String>[
      for (int w = 0; w < count; w++)
        engine.turnOn(from.addDays(w * 7))?.leader.displayName ?? '-',
    ];
  }

  /// A comparable fingerprint of everything a merge can affect.
  String shapeOf(Family f) => <String>[
    f.name,
    '${f.turnoverWeekday}',
    f.members.map((Member m) => '${m.id}:${m.displayName}').join(','),
    f.cycles
        .map((Cycle c) => '${c.id}@${c.effectiveFrom}:${c.order.join("-")}')
        .join(','),
    // `withdrawn` is part of the fingerprint on purpose: without it, a merge
    // that dropped a withdrawal would look identical to one that kept it,
    // and the commutativity tests below would pass through the bug.
    f.skips
        .map(
          (SkippedTurn s) =>
              '${s.id}@${s.weekStart}${s.withdrawn ? "(withdrawn)" : ""}',
        )
        .join(','),
  ].join('|');

  group('merging is deterministic', () {
    test('order of arguments does not change the result', () {
      final Family onPhoneA = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Cousin',
        today: anchor,
        ids: DistinctIdGenerator('a'),
      );
      final Family onPhoneB = FamilyEditor.removeMember(
        familyOfFour(),
        memberId: tata.id,
        today: anchor,
        ids: DistinctIdGenerator('b'),
      );

      expect(
        shapeOf(FamilyMerge.merge(onPhoneA, onPhoneB)),
        shapeOf(FamilyMerge.merge(onPhoneB, onPhoneA)),
        reason: 'two phones merging in opposite orders must agree',
      );
    });

    test('merging with itself changes nothing', () {
      final Family family = familyOfFour();
      expect(shapeOf(FamilyMerge.merge(family, family)), shapeOf(family));
    });

    test('merging is stable when applied twice', () {
      final Family a = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Cousin',
        today: anchor,
        ids: FakeIdGenerator(),
      );
      final Family b = familyOfFour();

      final Family once = FamilyMerge.merge(a, b);
      final Family twice = FamilyMerge.merge(once, b);

      expect(shapeOf(twice), shapeOf(once));
    });

    test('both phones name the same leader for every week', () {
      // Each phone writes an epoch effective from the same turnover.
      final Family onPhoneA = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Cousin',
        today: anchor,
        ids: DistinctIdGenerator('a'),
      );
      final Family onPhoneB = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Gogo',
        today: anchor,
        ids: DistinctIdGenerator('b'),
      );

      final Family seenByA = FamilyMerge.merge(onPhoneA, onPhoneB);
      final Family seenByB = FamilyMerge.merge(onPhoneB, onPhoneA);

      expect(
        leaders(seenByA, anchor, 20),
        leaders(seenByB, anchor, 20),
        reason: 'the two devices must not disagree about any week',
      );
    });
  });

  group('nothing is silently discarded', () {
    test('a cycle written on one phone survives the merge', () {
      final Family onPhoneA = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Cousin',
        today: anchor,
        ids: DistinctIdGenerator('a'),
      );
      final Family onPhoneB = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Gogo',
        today: anchor,
        ids: DistinctIdGenerator('b'),
      );

      final Family merged = FamilyMerge.merge(onPhoneA, onPhoneB);

      // Both epochs are present, even though only one can govern the week.
      expect(merged.cycles, hasLength(3));
      expect(
        merged.members.map((Member m) => m.displayName),
        containsAll(<String>['Cousin', 'Gogo']),
        reason: 'both people were really added; neither may vanish',
      );
    });

    test('a skip recorded on one phone survives', () {
      final Family withSkip = familyOfFour(
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: anchor, memberId: jabulile.id),
        ],
      );

      final Family merged = FamilyMerge.merge(withSkip, familyOfFour());

      expect(merged.skips, hasLength(1));
      expect(merged.skips.single.id, 's1');
    });

    test('skips from both phones are kept', () {
      final Family a = familyOfFour(
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: anchor, memberId: jabulile.id),
        ],
      );
      final Family b = familyOfFour(
        skips: <SkippedTurn>[
          SkippedTurn(
            id: 's2',
            weekStart: anchor.addDays(7),
            memberId: sisi.id,
          ),
        ],
      );

      expect(FamilyMerge.merge(a, b).skips, hasLength(2));
      expect(FamilyMerge.merge(b, a).skips, hasLength(2));
    });

    test('a rename made on one phone is not lost to the other', () {
      final Family renamed = familyOfFour().copyWith(
        members: const <Member>[
          Member(id: 'm1', displayName: 'Bhuti'),
          sisi,
          mama,
          tata,
        ],
      );
      // The other phone also did something, so it is the one with more
      // history and wins the scalars — the rename must still survive.
      final Family busier = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Cousin',
        today: anchor,
        ids: FakeIdGenerator(),
      );

      final Family merged = FamilyMerge.merge(renamed, busier);

      expect(
        merged.members.firstWhere((Member m) => m.id == 'm1').displayName,
        anyOf('Bhuti', 'Jabulile'),
      );
      // Whichever wins, both phones must agree on it.
      expect(
        shapeOf(FamilyMerge.merge(renamed, busier)),
        shapeOf(FamilyMerge.merge(busier, renamed)),
      );
    });
  });

  group('schema versions', () {
    test('the higher version wins, whichever side it is on', () {
      final Family older = familyOfFour();
      final Family newer = Family(
        id: 'f1',
        name: 'Mashibini',
        turnoverWeekday: DateTime.sunday,
        members: older.members,
        cycles: older.cycles,
        schemaVersion: older.schemaVersion + 1,
      );

      expect(
        FamilyMerge.merge(newer, older).schemaVersion,
        older.schemaVersion + 1,
      );
      expect(
        FamilyMerge.merge(older, newer).schemaVersion,
        older.schemaVersion + 1,
        reason: 'a merge must not quietly downgrade the schema',
      );
    });
  });

  group('what it refuses', () {
    test('two different families cannot be merged', () {
      final Family other = Family(
        id: 'f2',
        name: 'Someone else',
        turnoverWeekday: DateTime.sunday,
        members: const <Member>[jabulile, sisi],
        cycles: <Cycle>[
          Cycle(
            id: 'c1',
            effectiveFrom: anchor,
            order: const <String>['m1', 'm2'],
          ),
        ],
      );

      expect(
        () => FamilyMerge.merge(familyOfFour(), other),
        throwsArgumentError,
      );
    });
  });

  group('a withdrawn skip survives the merge (R1.4, R6.2)', () {
    /// One phone skips a week; both phones have that. Then one takes it back.
    (Family withdrawn, Family stillSkipped) phonesDisagreeingAboutASkip() {
      final Family skipped = FamilyEditor.skipTurn(
        familyOfFour(),
        weekStart: anchor.addDays(7),
        today: anchor,
        ids: DistinctIdGenerator('a'),
      );
      return (
        FamilyEditor.unskipTurn(skipped, weekStart: anchor.addDays(7)),
        skipped,
      );
    }

    test('the withdrawal wins, whichever side is holding it', () {
      final (Family withdrawn, Family stillSkipped) =
          phonesDisagreeingAboutASkip();

      for (final Family merged in <Family>[
        FamilyMerge.merge(withdrawn, stillSkipped),
        FamilyMerge.merge(stillSkipped, withdrawn),
      ]) {
        expect(merged.skips.single.withdrawn, isTrue);
        expect(
          leaders(merged, anchor.addDays(7), 1).single,
          'Sisi',
          reason: 'taking a skip back must not be undone by syncing',
        );
      }
    });

    test('merging again changes nothing', () {
      final (Family withdrawn, Family stillSkipped) =
          phonesDisagreeingAboutASkip();
      final Family once = FamilyMerge.merge(withdrawn, stillSkipped);

      expect(shapeOf(FamilyMerge.merge(once, stillSkipped)), shapeOf(once));
      expect(shapeOf(FamilyMerge.merge(once, once)), shapeOf(once));
    });

    test('a skip neither side withdrew is still a skip', () {
      final (Family _, Family stillSkipped) = phonesDisagreeingAboutASkip();

      final Family merged = FamilyMerge.merge(stillSkipped, stillSkipped);

      expect(merged.skips.single.withdrawn, isFalse);
      expect(leaders(merged, anchor.addDays(7), 1).single, 'Mama');
    });

    test('re-skipping after a withdrawal survives as a separate record', () {
      final (Family withdrawn, Family stillSkipped) =
          phonesDisagreeingAboutASkip();
      final Family again = FamilyEditor.skipTurn(
        withdrawn,
        weekStart: anchor.addDays(7),
        today: anchor,
        ids: DistinctIdGenerator('b'),
      );

      final Family merged = FamilyMerge.merge(again, stillSkipped);

      expect(merged.skips, hasLength(2));
      expect(
        leaders(merged, anchor.addDays(7), 1).single,
        'Mama',
        reason: 'the live skip counts; the withdrawn one does not',
      );
    });
  });

  group('the engine resolves a tie the same way everywhere', () {
    test('two epochs on the same date pick the same one on both phones', () {
      final Cycle fromA = Cycle(
        id: 'c-aaa',
        effectiveFrom: anchor.addDays(7),
        order: const <String>['m2', 'm1'],
        reason: CycleReason.reordered,
      );
      final Cycle fromB = Cycle(
        id: 'c-bbb',
        effectiveFrom: anchor.addDays(7),
        order: const <String>['m3', 'm4'],
        reason: CycleReason.reordered,
      );

      final Family asA = familyOfFour().copyWith(
        cycles: <Cycle>[...familyOfFour().cycles, fromA, fromB],
      );
      final Family asB = familyOfFour().copyWith(
        cycles: <Cycle>[...familyOfFour().cycles, fromB, fromA],
      );

      expect(
        leaders(asA, anchor.addDays(7), 4),
        leaders(asB, anchor.addDays(7), 4),
        reason: 'the tie-break must not depend on the order they arrived in',
      );
    });
  });
}
