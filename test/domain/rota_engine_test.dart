import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/skipped_turn.dart';
import 'package:mashibini_prayer/src/domain/entities/turn.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';

/// The worked example from docs/DATA-MODEL.md: four members, turnover on
/// Sunday, cycle starting Sunday 18 October 2026.
const Member jabulile = Member(id: 'm1', displayName: 'Jabulile');
const Member sisi = Member(id: 'm2', displayName: 'Sisi');
const Member mama = Member(id: 'm3', displayName: 'Mama');
const Member tata = Member(id: 'm4', displayName: 'Tata');

final CalendarDate start = CalendarDate(2026, 10, 18); // a Sunday

Map<String, Member> familyOfFour() => <String, Member>{
  jabulile.id: jabulile,
  sisi.id: sisi,
  mama.id: mama,
  tata.id: tata,
};

RotaEngine engineOf({
  List<SkippedTurn> skips = const <SkippedTurn>[],
  List<Cycle>? cycles,
  Map<String, Member>? members,
}) => RotaEngine(
  members: members ?? familyOfFour(),
  skips: skips,
  cycles:
      cycles ??
      <Cycle>[
        Cycle(
          id: 'c1',
          effectiveFrom: start,
          order: <String>[jabulile.id, sisi.id, mama.id, tata.id],
        ),
      ],
);

/// Leader names for [count] consecutive weeks from [start].
List<String> leadersFor(RotaEngine engine, int count) => <String>[
  for (int i = 0; i < count; i++)
    engine.turnOn(start.addDays(i * 7))!.leader.displayName,
];

void main() {
  group('the ordinary case', () {
    test('six consecutive weeks run through the order and repeat', () {
      expect(leadersFor(engineOf(), 6), <String>[
        'Jabulile',
        'Sisi',
        'Mama',
        'Tata',
        'Jabulile',
        'Sisi',
      ]);
    });

    test('a turn runs from its turnover day to the day before the next', () {
      final Turn turn = engineOf().turnOn(start)!;
      expect(turn.weekStart, start);
      expect(turn.weekEnd, CalendarDate(2026, 10, 24));
      expect(turn.weekEnd.addDays(1).weekday, DateTime.sunday);
    });

    test('every day of a week has the same leader (R1.2)', () {
      final RotaEngine engine = engineOf();
      final Set<String> leaders = <String>{
        for (int i = 0; i < 7; i++)
          engine.turnOn(start.addDays(7 + i))!.leader.displayName,
      };
      expect(leaders, <String>{'Sisi'});
    });

    test('the handover lands on the turnover day itself, not after it', () {
      final RotaEngine engine = engineOf();
      expect(engine.turnOn(start.addDays(6))!.leader, jabulile);
      expect(engine.turnOn(start.addDays(7))!.leader, sisi);
    });
  });

  group('skips (R1.4)', () {
    test('a skipped week passes to the next member', () {
      final RotaEngine engine = engineOf(
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: start, memberId: jabulile.id),
        ],
      );
      expect(leadersFor(engine, 4), <String>[
        'Sisi',
        'Mama',
        'Tata',
        'Jabulile',
      ]);
    });

    test('the skipped member is not owed a double turn later', () {
      final RotaEngine engine = engineOf(
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: start, memberId: jabulile.id),
        ],
      );
      final List<String> twoCycles = leadersFor(engine, 8);
      // Every member leads exactly twice across eight weeks — nobody is repaid.
      for (final String name in <String>['Jabulile', 'Sisi', 'Mama', 'Tata']) {
        expect(
          twoCycles.where((String n) => n == name).length,
          2,
          reason: '$name should lead twice in eight weeks, got $twoCycles',
        );
      }
    });

    test('two skips in one week advance by two', () {
      final RotaEngine engine = engineOf(
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: start, memberId: jabulile.id),
          SkippedTurn(id: 's2', weekStart: start, memberId: sisi.id),
        ],
      );
      expect(leadersFor(engine, 4), <String>[
        'Mama',
        'Tata',
        'Jabulile',
        'Sisi',
      ]);
    });

    test('a future skip does not affect earlier weeks', () {
      final RotaEngine engine = engineOf(
        skips: <SkippedTurn>[
          SkippedTurn(
            id: 's1',
            weekStart: start.addDays(21),
            memberId: tata.id,
          ),
        ],
      );
      expect(leadersFor(engine, 3), <String>['Jabulile', 'Sisi', 'Mama']);
      expect(engine.turnOn(start.addDays(21))!.leader, jabulile);
    });
  });

  group('no drift (R1.3)', () {
    test('six months untouched costs one modulo', () {
      final CalendarDate far = start.addDays(26 * 7);
      expect(engineOf().turnOn(far)!.leader, mama); // 26 % 4 == 2
    });

    test('ten years of weeks, every one correct', () {
      final RotaEngine engine = engineOf();
      final List<Member> order = <Member>[jabulile, sisi, mama, tata];
      final List<String> mismatches = <String>[];
      for (int i = 0; i < 521; i++) {
        final CalendarDate week = start.addDays(i * 7);
        final Member actual = engine.turnOn(week)!.leader;
        final Member expected = order[i % 4];
        if (actual != expected) {
          mismatches.add('week $i ($week): ${actual.id} != ${expected.id}');
        }
      }
      expect(mismatches, isEmpty);
    });

    test('a mid-week date far in the future is still correct', () {
      final CalendarDate midweek = start.addDays(100 * 7 + 3);
      expect(engineOf().turnOn(midweek)!.leader, jabulile); // 100 % 4 == 0
    });
  });

  group('before the rota existed', () {
    test('a date before the first cycle has no leader, not a guess', () {
      expect(engineOf().turnOn(start.subtractDays(1)), isNull);
      expect(engineOf().turnOn(start.subtractDays(700)), isNull);
    });

    test('startedOn reports when it began', () {
      expect(engineOf().startedOn, start);
    });

    test('turnsFrom stops rather than inventing turns', () {
      expect(engineOf().turnsFrom(start.subtractDays(14), count: 4), isEmpty);
    });
  });

  group('cycle epochs (R2.3)', () {
    // A fifth member joins four weeks in.
    const Member cousin = Member(id: 'm5', displayName: 'Cousin');
    final CalendarDate joinDate = start.addDays(28);

    RotaEngine withNewMember() => engineOf(
      members: <String, Member>{...familyOfFour(), cousin.id: cousin},
      cycles: <Cycle>[
        Cycle(
          id: 'c1',
          effectiveFrom: start,
          order: <String>[jabulile.id, sisi.id, mama.id, tata.id],
        ),
        Cycle(
          id: 'c2',
          effectiveFrom: joinDate,
          order: <String>[jabulile.id, sisi.id, mama.id, tata.id, cousin.id],
          reason: CycleReason.memberAdded,
        ),
      ],
    );

    test('adding a member does not rewrite history', () {
      final RotaEngine engine = withNewMember();
      expect(leadersFor(engine, 4), <String>[
        'Jabulile',
        'Sisi',
        'Mama',
        'Tata',
      ]);
    });

    test('the new epoch starts its own count from its own date', () {
      final RotaEngine engine = withNewMember();
      expect(engine.turnOn(joinDate)!.leader, jabulile);
      expect(engine.turnOn(joinDate.addDays(28))!.leader, cousin);
    });

    test('a skip in an earlier epoch does not shift a later one', () {
      final RotaEngine engine = RotaEngine(
        members: <String, Member>{...familyOfFour(), cousin.id: cousin},
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: start, memberId: jabulile.id),
        ],
        cycles: <Cycle>[
          Cycle(
            id: 'c1',
            effectiveFrom: start,
            order: <String>[jabulile.id, sisi.id, mama.id, tata.id],
          ),
          Cycle(
            id: 'c2',
            effectiveFrom: joinDate,
            order: <String>[jabulile.id, sisi.id, mama.id, tata.id, cousin.id],
            reason: CycleReason.memberAdded,
          ),
        ],
      );
      expect(engine.turnOn(start)!.leader, sisi); // skip applies here
      expect(engine.turnOn(joinDate)!.leader, jabulile); // but not here
    });

    test('a removed member still holds the turns they actually led', () {
      final RotaEngine engine = engineOf(
        cycles: <Cycle>[
          Cycle(
            id: 'c1',
            effectiveFrom: start,
            order: <String>[jabulile.id, sisi.id, mama.id, tata.id],
          ),
          Cycle(
            id: 'c2',
            effectiveFrom: start.addDays(28),
            order: <String>[jabulile.id, sisi.id, mama.id],
            reason: CycleReason.memberRemoved,
          ),
        ],
      );
      expect(engine.turnOn(start.addDays(21))!.leader, tata);
      expect(engine.turnOn(start.addDays(28))!.leader, jabulile);
      expect(
        engine
            .turnsFrom(start.addDays(28), count: 3)
            .map((Turn t) => t.leader.displayName),
        <String>['Jabulile', 'Sisi', 'Mama'],
      );
    });
  });

  group('the schedule ahead (R1.5)', () {
    test('returns the asked-for number of turns, in order, a week apart', () {
      final List<Turn> turns = engineOf().turnsFrom(start, count: 8);
      expect(turns, hasLength(8));
      expect(turns.first.weekStart, start);
      for (int i = 1; i < turns.length; i++) {
        expect(turns[i - 1].weekStart.daysUntil(turns[i].weekStart), 7);
      }
    });

    test('starts from the week containing the date, not the date', () {
      expect(engineOf().turnsFrom(start.addDays(3)).first.weekStart, start);
    });

    test('consecutive turns are contiguous, with no gap and no overlap', () {
      final List<Turn> turns = engineOf().turnsFrom(start, count: 6);
      for (int i = 1; i < turns.length; i++) {
        expect(
          turns[i - 1].weekEnd.addDays(1),
          turns[i].weekStart,
          reason:
              'turn ${i - 1} ends ${turns[i - 1].weekEnd}, '
              'turn $i starts ${turns[i].weekStart} - the weeks must abut',
        );
        expect(
          turns[i - 1].contains(turns[i].weekStart),
          isFalse,
          reason: 'turn ${i - 1} must not contain the next turn\'s first day',
        );
      }
    });

    test('a turn contains the date it was asked about', () {
      final RotaEngine engine = engineOf();
      for (int offset = 0; offset < 30; offset++) {
        final CalendarDate date = start.addDays(offset);
        expect(
          engine.turnOn(date)!.contains(date),
          isTrue,
          reason: '$date should fall inside the turn computed for it',
        );
      }
    });

    test('a count of zero or less asks for nothing', () {
      expect(engineOf().turnsFrom(start, count: 0), isEmpty);
      expect(engineOf().turnsFrom(start, count: -3), isEmpty);
    });
  });

  group('data that has drifted', () {
    test('an id with no member is dropped, and reported', () {
      final RotaEngine engine = engineOf(
        cycles: <Cycle>[
          Cycle(
            id: 'c1',
            effectiveFrom: start,
            order: <String>[jabulile.id, 'ghost', mama.id, tata.id],
          ),
        ],
      );
      expect(engine.unresolvedMemberIds, <String>{'ghost'});
      // The rota carries on with the three who remain.
      expect(leadersFor(engine, 4), <String>[
        'Jabulile',
        'Mama',
        'Tata',
        'Jabulile',
      ]);
    });

    test('a cycle whose members are all unknown has no leader', () {
      final RotaEngine engine = engineOf(
        cycles: <Cycle>[
          Cycle(id: 'c1', effectiveFrom: start, order: <String>['x', 'y']),
        ],
      );
      expect(engine.turnOn(start), isNull);
    });

    test('nothing is unresolved in a healthy rota', () {
      expect(engineOf().unresolvedMemberIds, isEmpty);
    });
  });

  group('a family that moved the day it hands over', () {
    final CalendarDate shortWeek = CalendarDate(2026, 11, 8); // a Sunday
    final CalendarDate newEpoch = CalendarDate(2026, 11, 11); // a Wednesday

    final Cycle sundays = Cycle(
      id: 'c1',
      effectiveFrom: start,
      order: <String>[jabulile.id, sisi.id, mama.id, tata.id],
    );
    final Cycle wednesdays = Cycle(
      id: 'c2',
      effectiveFrom: newEpoch,
      order: <String>[jabulile.id, sisi.id, mama.id, tata.id],
      reason: CycleReason.turnoverDayChanged,
    );

    RotaEngine moved() => engineOf(cycles: <Cycle>[sundays, wednesdays]);

    test('the dates are the ones the comment claims', () {
      expect(start.weekday, DateTime.sunday);
      expect(shortWeek.weekday, DateTime.sunday);
      expect(newEpoch.weekday, DateTime.wednesday);
    });

    test('every week before the change answers exactly as it did', () {
      final RotaEngine before = engineOf(cycles: <Cycle>[sundays]);
      final RotaEngine after = moved();
      for (
        CalendarDate date = start;
        date.isBefore(shortWeek);
        date = date.addDays(1)
      ) {
        expect(
          after.turnOn(date),
          before.turnOn(date),
          reason: 'moving the turnover day re-slices $date',
        );
      }
    });

    test('the last week of the old epoch is short, and says so', () {
      final Turn turn = moved().turnOn(shortWeek)!;
      expect(turn.leader, tata);
      expect(turn.weekStart, shortWeek);
      expect(turn.weekEnd, CalendarDate(2026, 11, 10));
      expect(
        turn.weekStart.daysUntil(turn.weekEnd),
        2,
        reason: 'three days, because the calendar does not divide evenly',
      );
    });

    test('the new epoch starts on its own day, with the next person', () {
      final Turn turn = moved().turnOn(newEpoch)!;
      expect(turn.leader, jabulile);
      expect(turn.weekStart, newEpoch);
      expect(turn.weekEnd, CalendarDate(2026, 11, 17));
    });

    test('no day belongs to two turns, and none to nobody', () {
      final RotaEngine engine = moved();
      for (
        CalendarDate date = start;
        date.isBefore(CalendarDate(2027, 2, 1));
        date = date.addDays(1)
      ) {
        final Turn? turn = engine.turnOn(date);
        expect(turn, isNotNull, reason: '$date has no turn');
        expect(
          turn!.contains(date),
          isTrue,
          reason: '$date resolved to a turn it is not inside: $turn',
        );
      }
    });

    test('walking forwards lands on the short week, not over it', () {
      final List<Turn> turns = moved().turnsFrom(shortWeek, count: 3);
      expect(turns.map((Turn t) => t.weekStart).toList(), <CalendarDate>[
        shortWeek,
        newEpoch,
        CalendarDate(2026, 11, 18),
      ]);
      expect(turns.map((Turn t) => t.leader.displayName).toList(), <String>[
        'Tata',
        'Jabulile',
        'Sisi',
      ]);
    });

    test('consecutive turns meet with no gap and no overlap', () {
      final List<Turn> turns = moved().turnsFrom(start, count: 12);
      for (int i = 1; i < turns.length; i++) {
        expect(
          turns[i].weekStart,
          turns[i - 1].weekEnd.addDays(1),
          reason: '${turns[i - 1]} does not hand over to ${turns[i]}',
        );
      }
    });

    test('which day it turns over on is a question about a date', () {
      final RotaEngine engine = moved();
      expect(engine.turnoverWeekdayOn(start), DateTime.sunday);
      expect(engine.turnoverWeekdayOn(shortWeek), DateTime.sunday);
      expect(
        engine.turnoverWeekdayOn(CalendarDate(2026, 11, 10)),
        DateTime.sunday,
      );
      expect(engine.turnoverWeekdayOn(newEpoch), DateTime.wednesday);
      expect(
        engine.turnoverWeekdayOn(CalendarDate(2027, 1, 1)),
        DateTime.wednesday,
      );
    });

    test('a date before the rota began still has no leader', () {
      expect(moved().turnOn(start.subtractDays(1)), isNull);
    });

    test('a skip in the short week moves the new epoch along with it', () {
      final RotaEngine engine = engineOf(
        cycles: <Cycle>[sundays, wednesdays],
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: shortWeek, memberId: tata.id),
        ],
      );
      expect(engine.turnOn(shortWeek)!.leader, jabulile);
      expect(engine.turnOn(newEpoch)!.leader, jabulile);
    });
  });

  group('invalid construction is refused', () {
    test('there must be at least one cycle', () {
      expect(
        () => RotaEngine(members: familyOfFour(), cycles: const <Cycle>[]),
        throwsArgumentError,
      );
    });

    test('cycles given out of order are sorted, not trusted', () {
      final RotaEngine engine = engineOf(
        cycles: <Cycle>[
          Cycle(
            id: 'c2',
            effectiveFrom: start.addDays(28),
            order: <String>[tata.id],
            reason: CycleReason.reordered,
          ),
          Cycle(
            id: 'c1',
            effectiveFrom: start,
            order: <String>[jabulile.id, sisi.id, mama.id, tata.id],
          ),
        ],
      );
      expect(engine.startedOn, start);
      expect(engine.turnOn(start)!.leader, jabulile);
      expect(engine.turnOn(start.addDays(28))!.leader, tata);
    });
  });

  group('a rota of two', () {
    test('alternates', () {
      final RotaEngine engine = engineOf(
        members: <String, Member>{jabulile.id: jabulile, mama.id: mama},
        cycles: <Cycle>[
          Cycle(
            id: 'c1',
            effectiveFrom: start,
            order: <String>[jabulile.id, mama.id],
          ),
        ],
      );
      expect(leadersFor(engine, 4), <String>[
        'Jabulile',
        'Mama',
        'Jabulile',
        'Mama',
      ]);
    });
  });
}
