import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_setup.dart';

import '../support/fake_id_generator.dart';
import '../support/family_fixtures.dart';

void main() {
  const List<Member> four = <Member>[jabulile, sisi, mama, tata];

  Family build({
    String currentLeaderId = 'm1',
    List<Member> members = four,
    int turnoverWeekday = DateTime.sunday,
    CalendarDate? today,
  }) => RotaSetup.build(
    familyId: 'f1',
    familyName: 'Mashibini',
    members: members,
    turnoverWeekday: turnoverWeekday,
    currentLeaderId: currentLeaderId,
    today: today ?? anchor,
    ids: FakeIdGenerator(),
  );

  group('the answers a person can give', () {
    test('whoever was named is leading today', () {
      for (final Member member in four) {
        final Family family = build(currentLeaderId: member.id);
        expect(
          RotaEngine.forFamily(family).turnOn(anchor)!.leader,
          member,
          reason: '${member.displayName} was named as leading this week',
        );
      }
    });

    test('the order after the current leader is the order as typed', () {
      final Family family = build(currentLeaderId: mama.id);
      final RotaEngine engine = RotaEngine.forFamily(family);

      expect(
        <String>[
          for (int w = 0; w < 4; w++)
            engine.turnOn(anchor.addDays(w * 7))!.leader.displayName,
        ],
        <String>['Mama', 'Tata', 'Jabulile', 'Sisi'],
      );
    });

    test('the anchor is this week, not a date in the past', () {
      final Family family = build(currentLeaderId: tata.id);
      expect(family.cycles.single.effectiveFrom, anchor);
      expect(RotaEngine.forFamily(family).startedOn, anchor);
    });

    test('setting up mid-week anchors to the week that is already running', () {
      // Wednesday of the first week.
      final Family family = build(today: anchor.addDays(3));
      expect(family.cycles.single.effectiveFrom, anchor);
      expect(
        RotaEngine.forFamily(family).turnOn(anchor.addDays(3))!.leader,
        jabulile,
      );
    });

    test('the members are kept in the order they were typed', () {
      final Family family = build(currentLeaderId: tata.id);
      expect(family.members, four);
    });

    test('works for every turnover weekday', () {
      for (
        int weekday = DateTime.monday;
        weekday <= DateTime.sunday;
        weekday++
      ) {
        final Family family = build(turnoverWeekday: weekday);
        expect(family.cycles.single.effectiveFrom.weekday, weekday);
        expect(
          RotaEngine.forFamily(family).turnOn(anchor)!.leader,
          jabulile,
          reason: 'turnover on weekday $weekday',
        );
      }
    });

    test('nobody has to know what an anchor is (R2.2)', () {
      // The caller supplies only answerable things; no date arithmetic.
      final Family family = RotaSetup.build(
        familyId: 'f1',
        familyName: 'Mashibini',
        members: four,
        turnoverWeekday: DateTime.sunday,
        currentLeaderId: sisi.id,
        today: anchor.addDays(5),
        ids: FakeIdGenerator(),
      );

      final RotaEngine engine = RotaEngine.forFamily(family);
      expect(engine.turnOn(anchor.addDays(5))!.leader, sisi);
      expect(engine.turnOn(anchor.addDays(12))!.leader, mama);
    });
  });

  group('answers that cannot make a rota', () {
    test('fewer than two people', () {
      expect(
        () => build(members: const <Member>[jabulile]),
        throwsArgumentError,
      );
      expect(() => build(members: const <Member>[]), throwsArgumentError);
    });

    test('a leader who is not in the family', () {
      expect(() => build(currentLeaderId: 'nobody'), throwsArgumentError);
    });

    test('two members sharing an id', () {
      expect(
        () => build(
          members: const <Member>[
            jabulile,
            Member(id: 'm1', displayName: 'Also Jabulile'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a weekday that is not a weekday', () {
      expect(() => build(turnoverWeekday: 0), throwsArgumentError);
      expect(() => build(turnoverWeekday: 8), throwsArgumentError);
    });
  });
}
