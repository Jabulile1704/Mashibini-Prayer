import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/skipped_turn.dart';
import 'package:mashibini_prayer/src/domain/entities/turn.dart';

/// The value types carry equality because the UI will rebuild on it and the
/// tests compare on it. An entity whose `==` is wrong fails quietly, which is
/// why these are tested rather than assumed.
void main() {
  group('CalendarDate, the remaining surface', () {
    test('reads the calendar date out of a real clock reading', () {
      final DateTime moment = DateTime(2026, 10, 18, 23, 59, 59);
      expect(CalendarDate.from(moment), CalendarDate(2026, 10, 18));
    });

    test('a late-evening local time does not roll into the next day', () {
      // The type holds midnight UTC internally; a naive conversion of a
      // UTC+2 evening would land on the 19th.
      expect(
        CalendarDate.from(DateTime(2026, 10, 18, 22, 30)),
        CalendarDate(2026, 10, 18),
      );
    });

    test('isAfter and isOnOrAfter', () {
      final CalendarDate day = CalendarDate(2026, 10, 18);
      expect(day.isAfter(CalendarDate(2026, 10, 17)), isTrue);
      expect(day.isAfter(day), isFalse);
      expect(day.isOnOrAfter(day), isTrue);
      expect(day.isOnOrAfter(CalendarDate(2026, 10, 19)), isFalse);
    });

    test('is not equal to a different date, or to another type', () {
      expect(CalendarDate(2026, 10, 18) == CalendarDate(2026, 10, 19), isFalse);
      // ignore: unrelated_type_equality_checks
      expect(CalendarDate(2026, 10, 18) == '2026-10-18', isFalse);
    });

    test('compareTo orders', () {
      expect(
        CalendarDate(2026, 1, 1).compareTo(CalendarDate(2026, 1, 2)),
        lessThan(0),
      );
      expect(
        CalendarDate(2026, 1, 2).compareTo(CalendarDate(2026, 1, 1)),
        greaterThan(0),
      );
      expect(CalendarDate(2026, 1, 1).compareTo(CalendarDate(2026, 1, 1)), 0);
    });
  });

  group('Member', () {
    test('equal by id and name', () {
      expect(
        const Member(id: 'm1', displayName: 'Mama'),
        const Member(id: 'm1', displayName: 'Mama'),
      );
      expect(
        const Member(id: 'm1', displayName: 'Mama').hashCode,
        const Member(id: 'm1', displayName: 'Mama').hashCode,
      );
    });

    test('a renamed member is a different value', () {
      expect(
        const Member(id: 'm1', displayName: 'Mama') ==
            const Member(id: 'm1', displayName: 'Mother'),
        isFalse,
      );
    });

    test('a different person with the same name is a different value', () {
      expect(
        const Member(id: 'm1', displayName: 'Sisi') ==
            const Member(id: 'm2', displayName: 'Sisi'),
        isFalse,
      );
    });

    test('describes itself usefully in a failure message', () {
      expect(
        const Member(id: 'm1', displayName: 'Mama').toString(),
        'Member(m1, Mama)',
      );
    });
  });

  group('Cycle', () {
    test('refuses to exist with no members', () {
      expect(
        () => Cycle(
          id: 'c1',
          effectiveFrom: CalendarDate(2026, 10, 18),
          order: const <String>[],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('defaults to the initial reason', () {
      final Cycle cycle = Cycle(
        id: 'c1',
        effectiveFrom: CalendarDate(2026, 10, 18),
        order: const <String>['m1'],
      );
      expect(cycle.reason, CycleReason.initial);
    });

    test('describes itself usefully', () {
      final Cycle cycle = Cycle(
        id: 'c1',
        effectiveFrom: CalendarDate(2026, 10, 18),
        order: const <String>['m1', 'm2'],
      );
      expect(cycle.toString(), 'Cycle(c1, from 2026-10-18, 2 members)');
    });
  });

  group('SkippedTurn', () {
    test('carries an optional note', () {
      final SkippedTurn skip = SkippedTurn(
        id: 's1',
        weekStart: CalendarDate(2026, 10, 18),
        memberId: 'm1',
      );
      expect(skip.note, isNull);
      expect(
        SkippedTurn(
          id: 's2',
          weekStart: CalendarDate(2026, 10, 18),
          memberId: 'm1',
          note: 'away',
        ).note,
        'away',
      );
    });

    test('describes itself usefully', () {
      expect(
        SkippedTurn(
          id: 's1',
          weekStart: CalendarDate(2026, 10, 18),
          memberId: 'm1',
        ).toString(),
        'SkippedTurn(m1, week of 2026-10-18)',
      );
    });
  });

  group('Turn', () {
    final Turn turn = Turn(
      leader: const Member(id: 'm1', displayName: 'Mama'),
      weekStart: CalendarDate(2026, 10, 18),
      weekEnd: CalendarDate(2026, 10, 24),
    );

    test('contains every day of its own week', () {
      for (int i = 0; i < 7; i++) {
        expect(
          turn.contains(CalendarDate(2026, 10, 18).addDays(i)),
          isTrue,
          reason: 'day +$i should be inside the turn',
        );
      }
    });

    test('contains neither the day before nor the day after', () {
      expect(turn.contains(CalendarDate(2026, 10, 17)), isFalse);
      expect(turn.contains(CalendarDate(2026, 10, 25)), isFalse);
    });

    test('equal by leader and dates', () {
      expect(
        turn,
        Turn(
          leader: const Member(id: 'm1', displayName: 'Mama'),
          weekStart: CalendarDate(2026, 10, 18),
          weekEnd: CalendarDate(2026, 10, 24),
        ),
      );
      expect(
        turn.hashCode,
        Turn(
          leader: const Member(id: 'm1', displayName: 'Mama'),
          weekStart: CalendarDate(2026, 10, 18),
          weekEnd: CalendarDate(2026, 10, 24),
        ).hashCode,
      );
    });

    test('a different leader in the same week is a different turn', () {
      expect(
        turn ==
            Turn(
              leader: const Member(id: 'm2', displayName: 'Tata'),
              weekStart: CalendarDate(2026, 10, 18),
              weekEnd: CalendarDate(2026, 10, 24),
            ),
        isFalse,
      );
    });

    test('describes itself usefully', () {
      expect(turn.toString(), 'Turn(Mama, 2026-10-18 to 2026-10-24)');
    });
  });
}
