import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/reminders/reminder_plan.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';

import '../support/fake_id_generator.dart';
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

  /// Only the reminders about a week this person leads.
  ///
  /// Every test written before #165 meant this by "the plan". The handover
  /// nudge is the other end of the same week, so it doubles the list
  /// without changing what any of them were asserting.
  List<Reminder> own(List<Reminder> all) =>
      all.where((Reminder r) => !r.isHandover).toList();

  group('whose phone is reminded (R5.1)', () {
    test("only about this person's own turns", () {
      for (final Member member in <Member>[jabulile, sisi, mama, tata]) {
        final List<Reminder> mine = own(plan(youAre: member.id));

        for (final Reminder reminder in mine) {
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
      expect(own(plan(youAre: jabulile.id, horizon: 3)), hasLength(3));
      expect(own(plan(youAre: jabulile.id, horizon: 8)), hasLength(8));
    });

    test("the first one is this person's next turn, not the next turnover", () {
      final List<Reminder> mine = plan(youAre: mama.id);

      expect(mine.first.turnStarts, anchor.addDays(14));
      expect(mine.first.at, DateTime(2026, 10, 31, 19));
    });

    test('reminders are in order, and a cycle apart', () {
      final List<Reminder> everything = plan(youAre: tata.id);
      for (int i = 1; i < everything.length; i++) {
        expect(everything[i].at.isAfter(everything[i - 1].at), isTrue);
      }

      final List<Reminder> mine = own(everything);
      for (int i = 1; i < mine.length; i++) {
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
      expect(first.body, isNot(contains('Jabulile')));
    });
  });

  group('moments that have passed', () {
    test('a reminder already due is not scheduled', () {
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

      expect(own(mine), hasLength(5));
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

  group('after the family moves the day it hands over (#100)', () {
    final Family moved = FamilyEditor.changeTurnoverDay(
      familyOfFour(),
      weekday: DateTime.wednesday,
      today: CalendarDate(2026, 11, 3),
      ids: FakeIdGenerator(),
    );

    test('the reminder moves with it, rather than staying on Saturdays', () {
      final List<Reminder> mine = ReminderPlan.forDevice(
        family: moved,
        youAre: jabulile.id,
        today: CalendarDate(2026, 11, 3),
        now: DateTime(2026, 11, 3, 8),
        horizon: 2,
      );

      expect(mine.first.turnStarts, CalendarDate(2026, 11, 11));
      expect(mine.first.at, DateTime(2026, 11, 10, 19));
      expect(
        mine.first.at.weekday,
        DateTime.tuesday,
        reason: 'the evening before a Wednesday turnover is a Tuesday',
      );
    });

    test('the short week is reminded about too, and only once', () {
      // Tata's last Sunday week is three days long. It is still their turn.
      final List<Reminder> theirs = ReminderPlan.forDevice(
        family: moved,
        youAre: tata.id,
        today: CalendarDate(2026, 11, 3),
        now: DateTime(2026, 11, 3, 8),
        horizon: 3,
      );

      expect(
        own(theirs).map((Reminder r) => r.turnStarts).toList(),
        <CalendarDate>[
          CalendarDate(2026, 11, 8), // the short week
          CalendarDate(2026, 12, 2), // their first Wednesday week
          CalendarDate(2026, 12, 30),
        ],
      );
      expect(
        theirs.map((Reminder r) => r.id).toSet(),
        hasLength(theirs.length),
        reason: 'two reminders sharing an id would replace each other',
      );
    });
  });

  group('the handover nudge (#165)', () {
    /// Only the reminders about handing over to somebody else.
    List<Reminder> handovers(List<Reminder> all) =>
        all.where((Reminder r) => r.isHandover).toList();

    test('each of this person\'s weeks gets one', () {
      final List<Reminder> mine = plan(youAre: jabulile.id, horizon: 3);

      expect(handovers(mine), hasLength(3));
      expect(own(mine), hasLength(3));
    });

    test('it lands the evening the week ends, not the evening it starts', () {
      // Jabulile leads from Sunday 18 October to Saturday 24 October.
      final Reminder handover = handovers(plan(youAre: jabulile.id, horizon: 1))
          .single;

      expect(handover.at, DateTime(2026, 10, 24, 19));
      expect(handover.turnStarts, anchor.addDays(7));
    });

    test('and names whoever is next, because that is the whole point', () {
      final Reminder handover = handovers(plan(youAre: jabulile.id, horizon: 1))
          .single;

      expect(handover.title, 'Your week ends tomorrow');
      expect(handover.body, startsWith('Sisi leads'));
      expect(handover.body, contains('telling them'));
    });

    test('the next person is read from the rota, not from the order', () {
      // Sisi's week is skipped, so Jabulile hands over to Mama.
      final Family skipped = FamilyEditor.skipTurn(
        familyOfFour(),
        weekStart: anchor.addDays(7),
        today: anchor,
        ids: FakeIdGenerator(),
      );
      final Reminder handover = handovers(
        plan(youAre: jabulile.id, family: skipped, horizon: 1),
      ).single;

      expect(handover.body, startsWith('Mama leads'));
    });

    test('an evening that has gone is not scheduled', () {
      final List<Reminder> mine = plan(
        youAre: jabulile.id,
        today: anchor.addDays(6),
        now: DateTime(2026, 10, 24, 20),
        horizon: 1,
      );

      expect(
        handovers(mine).first.turnStarts,
        isNot(anchor.addDays(7)),
        reason: 'the handover for this evening has already passed',
      );
    });

    test('nobody is told to tell themselves', () {
      // A rota of one is impossible through the app, but the engine will
      // answer for it, and the answer must not be "tell Jabulile".
      final Family alone = familyOfFour().copyWith(
        members: const <Member>[jabulile],
        cycles: <Cycle>[
          Cycle(id: 'c1', effectiveFrom: anchor, order: const <String>['m1']),
        ],
      );

      expect(
        plan(
          youAre: jabulile.id,
          family: alone,
        ).where((Reminder r) => r.isHandover),
        isEmpty,
      );
    });

    test('its id cannot collide with a turn reminder', () {
      // Both are derived from a date, and a notification id that repeats
      // means one reminder silently replaces another.
      final List<Reminder> everything = <Reminder>[
        for (final Member member in <Member>[jabulile, sisi, mama, tata])
          ...plan(youAre: member.id),
      ];

      expect(
        everything.map((Reminder r) => r.id).toSet(),
        hasLength(everything.length),
      );
      for (final Reminder reminder in everything) {
        expect(
          reminder.id,
          lessThan(2147483647),
          reason: 'a notification id has to fit in a 32-bit int',
        );
      }
    });

    test('and the phone it reaches is the one certain to be in use', () {
      // The argument for this feature, as a test rather than a comment:
      // the person being reminded has been leading prayer all week, so
      // their phone is the one that has been opened. #77 wanted to reach
      // the person who has not opened it, and the free tier cannot.
      final Reminder handover = handovers(plan(youAre: jabulile.id, horizon: 1))
          .single;
      final CalendarDate theWeekBefore = handover.turnStarts.subtractDays(7);

      expect(
        RotaEngine.forFamily(familyOfFour()).turnOn(theWeekBefore)!.leader.id,
        jabulile.id,
      );
    });
  });
}
