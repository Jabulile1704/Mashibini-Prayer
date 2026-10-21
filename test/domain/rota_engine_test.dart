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
  turnoverWeekday: DateTime.sunday,
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
        turnoverWeekday: DateTime.sunday,
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

  group('invalid construction is refused', () {
    test('a cycle must start on the turnover weekday', () {
      expect(
        () => RotaEngine(
          turnoverWeekday: DateTime.sunday,
          members: familyOfFour(),
          cycles: <Cycle>[
            Cycle(
              id: 'c1',
              effectiveFrom: CalendarDate(2026, 10, 19), // a Monday
              order: <String>[jabulile.id, sisi.id],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('there must be at least one cycle', () {
      expect(
        () => RotaEngine(
          turnoverWeekday: DateTime.sunday,
          members: familyOfFour(),
          cycles: const <Cycle>[],
        ),
        throwsArgumentError,
      );
    });

    test('the turnover weekday must be an ISO weekday', () {
      expect(
        () => RotaEngine(
          turnoverWeekday: 0,
          members: familyOfFour(),
          cycles: <Cycle>[
            Cycle(id: 'c1', effectiveFrom: start, order: <String>[jabulile.id]),
          ],
        ),
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
