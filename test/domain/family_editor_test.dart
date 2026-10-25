import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
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

  group('adding someone (R2.3)', () {
    test('this week is untouched, whatever day the change is made', () {
      for (int dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++) {
        final CalendarDate today = anchor.addDays(dayOfWeek);
        final Family after = FamilyEditor.addMember(
          familyOfFour(),
          displayName: 'Cousin',
          today: today,
          ids: FakeIdGenerator(),
        );
        expect(
          RotaEngine.forFamily(after).turnOn(today)!.leader,
          jabulile,
          reason:
              'adding on day +$dayOfWeek must not change the week in progress',
        );
      }
    });

    test('next week keeps the leader it was already going to have', () {
      final Family before = familyOfFour();
      final String wasNext = leaders(before, anchor.addDays(7), 1).single;

      final Family after = FamilyEditor.addMember(
        before,
        displayName: 'Cousin',
        today: anchor,
        ids: FakeIdGenerator(),
      );

      expect(leaders(after, anchor.addDays(7), 1).single, wasNext);
      expect(wasNext, 'Sisi');
    });

    test('they join at the end: everyone else leads first', () {
      final Family after = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Cousin',
        today: anchor,
        ids: FakeIdGenerator(),
      );

      expect(leaders(after, anchor.addDays(7), 6), <String>[
        'Sisi',
        'Mama',
        'Tata',
        'Jabulile',
        'Cousin',
        'Sisi',
      ]);
    });

    test('a new epoch is written rather than the old one edited', () {
      final Family after = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Cousin',
        today: anchor,
        ids: FakeIdGenerator(),
      );

      expect(after.cycles, hasLength(2));
      expect(after.cycles.first.order, familyOfFour().cycles.first.order);
      expect(after.cycles.last.effectiveFrom, anchor.addDays(7));
      expect(after.cycles.last.reason, CycleReason.memberAdded);
    });

    test('past turns are unchanged', () {
      final Family before = familyOfFour();
      final Family after = FamilyEditor.addMember(
        before,
        displayName: 'Cousin',
        today: anchor.addDays(21),
        ids: FakeIdGenerator(),
      );

      expect(
        leaders(after, anchor, 4),
        leaders(before, anchor, 4),
        reason: 'history must not move when the family changes',
      );
    });

    test('the new member gets an id nobody is using', () {
      final Family after = FamilyEditor.addMember(
        familyOfFour(),
        displayName: 'Cousin',
        today: anchor,
        ids: FakeIdGenerator(),
      );

      final Set<String> ids = <String>{
        for (final Member m in after.members) m.id,
      };
      // Uniqueness is the requirement; the particular id is the generator's
      // business. Asserting a value here would only be asserting the fake.
      expect(ids, hasLength(after.members.length));
      expect(ids, contains(after.members.last.id));
    });

    test('names are trimmed, and an empty one is refused', () {
      final Family after = FamilyEditor.addMember(
        familyOfFour(),
        displayName: '  Cousin  ',
        today: anchor,
        ids: FakeIdGenerator(),
      );
      expect(after.members.last.displayName, 'Cousin');

      expect(
        () => FamilyEditor.addMember(
          familyOfFour(),
          displayName: '   ',
          today: anchor,
          ids: FakeIdGenerator(),
        ),
        throwsArgumentError,
      );
    });

    test('adding twice stacks epochs without disturbing the first', () {
      // One generator for both edits: this is one phone, used twice. A fresh
      // generator per call would mint the same id twice, which is the bug
      // this whole mechanism exists to prevent.
      final FakeIdGenerator ids = FakeIdGenerator();
      Family family = familyOfFour();
      family = FamilyEditor.addMember(
        family,
        displayName: 'Cousin',
        today: anchor,
        ids: ids,
      );
      family = FamilyEditor.addMember(
        family,
        displayName: 'Gogo',
        today: anchor.addDays(7),
        ids: ids,
      );

      expect(family.cycles, hasLength(3));
      expect(leaders(family, anchor, 2), <String>['Jabulile', 'Sisi']);
      // Gogo joined a cycle that already had five people, so they lead sixth
      // — after Sisi, not in place of her. "At the end" means the end of the
      // cycle as it stood when they joined.
      expect(leaders(family, anchor.addDays(14), 6), <String>[
        'Mama',
        'Tata',
        'Jabulile',
        'Cousin',
        'Sisi',
        'Gogo',
      ]);
    });
  });

  group('changing a rota that has not started yet', () {
    test('adding somebody keeps the order the setup chose', () {
      // The family set up on a Sunday for a rota beginning the following one.
      final Family notYetRunning = Family(
        id: 'f1',
        name: 'Mashibini',
        turnoverWeekday: DateTime.sunday,
        members: const <Member>[jabulile, sisi],
        cycles: <Cycle>[
          Cycle(
            id: 'c1',
            effectiveFrom: anchor.addDays(28),
            order: const <String>['m1', 'm2'],
          ),
        ],
      );

      final Family after = FamilyEditor.addMember(
        notYetRunning,
        displayName: 'Cousin',
        today: anchor,
        ids: FakeIdGenerator(),
      );

      // Nothing has led yet, so there is no leader to preserve; the order
      // stands as it was, with the new person at the end.
      expect(after.cycles.last.order, <String>['m1', 'm2', 'm-1']);
      expect(RotaEngine.forFamily(after).turnOn(anchor), isNull);
    });
  });

  group('removing someone (R2.3)', () {
    test('this week is untouched', () {
      final Family after = FamilyEditor.removeMember(
        familyOfFour(),
        memberId: tata.id,
        today: anchor.addDays(2),
        ids: FakeIdGenerator(),
      );

      expect(
        RotaEngine.forFamily(after).turnOn(anchor.addDays(2))!.leader,
        jabulile,
      );
    });

    test('they stop taking turns from the next turnover', () {
      final Family after = FamilyEditor.removeMember(
        familyOfFour(),
        memberId: tata.id,
        today: anchor,
        ids: FakeIdGenerator(),
      );

      expect(leaders(after, anchor.addDays(7), 5), <String>[
        'Sisi',
        'Mama',
        'Jabulile',
        'Sisi',
        'Mama',
      ]);
    });

    test('a turn they already led keeps their name', () {
      // Tata led the fourth week; remove them in the fifth.
      final Family before = familyOfFour();
      expect(leaders(before, anchor.addDays(21), 1).single, 'Tata');

      final Family after = FamilyEditor.removeMember(
        before,
        memberId: tata.id,
        today: anchor.addDays(28),
        ids: FakeIdGenerator(),
      );

      expect(leaders(after, anchor.addDays(21), 1).single, 'Tata');
      expect(
        after.members.map((Member m) => m.id),
        contains(tata.id),
        reason: 'the member must stay on the family so history can render',
      );
    });

    test('removing whoever was due next passes the turn on', () {
      // Sisi leads next week; remove Sisi.
      final Family after = FamilyEditor.removeMember(
        familyOfFour(),
        memberId: sisi.id,
        today: anchor,
        ids: FakeIdGenerator(),
      );

      expect(leaders(after, anchor.addDays(7), 3), <String>[
        'Mama',
        'Tata',
        'Jabulile',
      ]);
    });

    test('a rota cannot be reduced below two people', () {
      final Family three = FamilyEditor.removeMember(
        familyOfFour(),
        memberId: tata.id,
        today: anchor,
        ids: FakeIdGenerator(),
      );
      final Family two = FamilyEditor.removeMember(
        three,
        memberId: mama.id,
        today: anchor.addDays(7),
        ids: FakeIdGenerator(),
      );

      expect(
        () => FamilyEditor.removeMember(
          two,
          memberId: jabulile.id,
          today: anchor.addDays(14),
          ids: FakeIdGenerator(),
        ),
        throwsArgumentError,
      );
    });

    test('somebody not in the rota cannot be removed', () {
      expect(
        () => FamilyEditor.removeMember(
          familyOfFour(),
          memberId: 'nobody',
          today: anchor,
          ids: FakeIdGenerator(),
        ),
        throwsArgumentError,
      );
    });

    test('a member already removed cannot be removed again', () {
      final Family after = FamilyEditor.removeMember(
        familyOfFour(),
        memberId: tata.id,
        today: anchor,
        ids: FakeIdGenerator(),
      );

      expect(
        () => FamilyEditor.removeMember(
          after,
          memberId: tata.id,
          today: anchor.addDays(7),
          ids: FakeIdGenerator(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('who is in the rota now', () {
    test('is the current cycle, not everyone who ever was', () {
      final Family after = FamilyEditor.removeMember(
        familyOfFour(),
        memberId: tata.id,
        today: anchor,
        ids: FakeIdGenerator(),
      );

      expect(
        FamilyEditor.activeMembers(after, anchor).map((Member m) => m.id),
        <String>['m1', 'm2', 'm3', 'm4'],
        reason: 'this week still has the old rota',
      );
      expect(
        FamilyEditor.activeMembers(
          after,
          anchor.addDays(7),
        ).map((Member m) => m.displayName),
        <String>['Sisi', 'Mama', 'Jabulile'],
      );
      expect(after.members, hasLength(4));
    });
  });
}
