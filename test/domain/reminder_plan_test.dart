import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/reminders/reminder_plan.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';

import '../support/family_fixtures.dart';

void main() {
  // anchor is Sunday 18 October 2026; the rota is Jabulile, Sisi, Mama, Tata.
  final DateTime beforeItAllStarts = DateTime(2026, 10, 17, 8);

  List<Reminder> plan({
    String youAre = 'm1',
    CalendarDate? today,
    DateTime? now,
    Family? family,
    int horizon = ReminderPlan.horizon,
  }) => ReminderPlan.forDevice(
    family: family ?? familyOfFour(),
    youAre: youAre,
    today: today ?? anchor,
    now: now ?? beforeItAllStarts,
    horizon: horizon,
  );

  group('whose phone is reminded (R5.1)', () {
    test("only about this person's own turns", () {
      for (final Member member in <Member>[jabulile, sisi, mama, tata]) {
        final List<Reminder> mine = plan(youAre: member.id);

        for (final Reminder reminder in mine) {
          // Checked against the engine, not against itself. The first
          // version of this compared a date with itself and was true no
          // matter what the planner did — a test that cannot fail.
          expect(
            RotaEngine.forFamily(familyOfFour())
                .turnOn(reminder.turnStarts)!
                .leader
                .id,
            member.id,
            reason:
                '${member.displayName} was reminded about the week of '
                '${reminder.turnStarts}, which they do not lead',
          );
        }
        expect(
          mine,
          isNotEmpty,
          reason: '${member.displayName} gets reminders',
        );
      }
    });

    test('each reminder lands the evening before a turn that person leads', () {
      final List<Reminder> mine = plan(youAre: sisi.id);

      for (final Reminder reminder in mine) {
        expect(
          reminder.at.day,
          reminder.turnStarts.subtractDays(1).day,
          reason: 'the reminder should be the evening before',
        );
        expect(reminder.at.hour, 19);
      }
    });

    test(
      'a phone belonging to nobody in the family is reminded of nothing',
      () {
        expect(plan(youAre: 'who-is-this'), isEmpty);
      },
    );

    test('a removed member stops being reminded rather than erroring', () {
      // Their id is gone from the family entirely.
      final Family withoutTata = familyOfFour().copyWith(
        members: const <Member>[jabulile, sisi, mama],
      );

      expect(plan(youAre: tata.id, family: withoutTata), isEmpty);
    });
  });

  group('what it schedules', () {
    test("as many of this person's turns as the horizon allows", () {
      expect(plan(youAre: jabulile.id, horizon: 3), hasLength(3));
      expect(plan(youAre: jabulile.id, horizon: 8), hasLength(8));
    });

    test("the first one is this person's next turn, not the next turnover", () {
      // Mama leads the third week; the reminder is the evening before that,
      // not before Sisi's week.
      final List<Reminder> mine = plan(youAre: mama.id);

      expect(mine.first.turnStarts, anchor.addDays(14));
      expect(mine.first.at, DateTime(2026, 10, 31, 19));
    });

    test('reminders are in order, and a cycle apart', () {
      final List<Reminder> mine = plan(youAre: tata.id);

      for (int i = 1; i < mine.length; i++) {
        expect(mine[i].at.isAfter(mine[i - 1].at), isTrue);
        expect(
          mine[i - 1].turnStarts.daysUntil(mine[i].turnStarts),
          28,
          reason: 'four people, so turns are four weeks apart',
        );
      }
    });

    test('the text says what it needs to and nothing else', () {
      final Reminder first = plan(youAre: jabulile.id).first;

      expect(first.title, 'Your week starts tomorrow');
      expect(first.body, contains('leading family prayer'));
      // No name: it is this person phone, and being told your own name by
      // your own phone is strange.
      expect(first.body, isNot(contains('Jabulile')));
    });
  });

  group('moments that have passed', () {
    test('a reminder already due is not scheduled', () {
      // Standing on the evening of the 24th, after 19:00. Sisi week starts
      // on the 25th, so that reminder has been and gone.
      final List<Reminder> mine = plan(
        youAre: sisi.id,
        today: anchor.addDays(6),
        now: DateTime(2026, 10, 24, 20),
      );

      expect(mine.first.turnStarts, isNot(anchor.addDays(7)));
    });

    test('a reminder due later today is still scheduled', () {
      final List<Reminder> mine = plan(
        youAre: sisi.id,
        today: anchor.addDays(6),
        now: DateTime(2026, 10, 24, 9),
      );

      expect(mine.first.turnStarts, anchor.addDays(7));
      expect(mine.first.at, DateTime(2026, 10, 24, 19));
    });

    test('the horizon is still filled after skipping a passed one', () {
      final List<Reminder> mine = plan(
        youAre: sisi.id,
        today: anchor.addDays(6),
        now: DateTime(2026, 10, 24, 20),
        horizon: 5,
      );

      expect(mine, hasLength(5));
    });
  });

  group('ids', () {
    test('the same turnover always gets the same id', () {
      final List<Reminder> first = plan(youAre: jabulile.id);
      final List<Reminder> again = plan(youAre: jabulile.id);

      expect(
        first.map((Reminder r) => r.id),
        again.map((Reminder r) => r.id),
        reason: 're-planning must replace reminders, not stack duplicates',
      );
    });

    test('different turnovers get different ids', () {
      final List<Reminder> mine = plan(youAre: jabulile.id);
      final Set<int> ids = mine.map((Reminder r) => r.id).toSet();

      expect(ids, hasLength(mine.length));
    });

    test('an id encodes its date, so it can be read in a bug report', () {
      final Reminder first = plan(youAre: jabulile.id).first;

      expect(first.turnStarts, CalendarDate(2026, 10, 18));
      expect(first.id, 20261018);
    });
  });

  group('Reminder, as a value', () {
    Reminder sample({String title = 'Your week starts tomorrow'}) => Reminder(
      id: 20261018,
      at: DateTime(2026, 10, 17, 19),
      title: title,
      body: 'You are leading family prayer from tomorrow.',
      turnStarts: CalendarDate(2026, 10, 18),
    );

    test('is equal by all of its parts', () {
      expect(sample(), sample());
      expect(sample().hashCode, sample().hashCode);
      expect(sample() == sample(title: 'Different'), isFalse);
    });

    test('equality matters because re-planning compares before replacing', () {
      // Two plans computed from the same family on the same day must come
      // out equal, or every recompute looks like a change.
      final List<Reminder> first = plan(youAre: jabulile.id);
      final List<Reminder> again = plan(youAre: jabulile.id);

      expect(first, again);
    });

    test('describes itself by its date, which is what identifies it', () {
      expect(
        sample().toString(),
        'Reminder(2026-10-18, at 2026-10-17 19:00:00.000)',
      );
    });
  });

  group('a rota that has not started', () {
    test('plans nothing rather than guessing', () {
      final Family later = familyOfFour();
      expect(
        ReminderPlan.forDevice(
          family: later,
          youAre: jabulile.id,
          today: anchor.subtractDays(30),
          now: DateTime(2026, 9, 1),
        ),
        isEmpty,
      );
    });
  });
}
