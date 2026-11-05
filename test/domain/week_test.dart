import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/rota/week.dart';

void main() {
  group('Week.startOf', () {
    // 18 October 2026 is a Sunday.
    final CalendarDate sunday = CalendarDate(2026, 10, 18);

    test('a turnover day is its own week start', () {
      expect(Week.startOf(sunday, DateTime.sunday), sunday);
    });

    test('every day of a week resolves to the same start', () {
      for (int i = 0; i < 7; i++) {
        expect(
          Week.startOf(sunday.addDays(i), DateTime.sunday),
          sunday,
          reason: 'day +$i should belong to the week beginning $sunday',
        );
      }
    });

    test('the day before belongs to the previous week', () {
      expect(
        Week.startOf(sunday.subtractDays(1), DateTime.sunday),
        sunday.subtractDays(7),
      );
    });

    test('works for every possible turnover weekday', () {
      for (
        int weekday = DateTime.monday;
        weekday <= DateTime.sunday;
        weekday++
      ) {
        final CalendarDate start = Week.startOf(sunday, weekday);
        expect(start.weekday, weekday);
        expect(start.isOnOrBefore(sunday), isTrue);
        expect(sunday.daysUntil(start), greaterThan(-7));
      }
    });

    test('endOf is the day before the next turnover', () {
      expect(Week.endOf(sunday, DateTime.sunday), CalendarDate(2026, 10, 24));
      expect(
        Week.endOf(sunday, DateTime.sunday).addDays(1).weekday,
        DateTime.sunday,
      );
    });

    test('rejects a weekday outside 1..7', () {
      expect(() => Week.startOf(sunday, 0), throwsArgumentError);
      expect(() => Week.startOf(sunday, 8), throwsArgumentError);
    });
  });

  group('Week.onOrAfter', () {
    final CalendarDate sunday18 = CalendarDate(2026, 10, 18);

    test('a date already on that day is its own answer', () {
      expect(Week.onOrAfter(sunday18, DateTime.sunday), sunday18);
    });

    test('otherwise the next one, between one and six days later', () {
      expect(Week.onOrAfter(sunday18, DateTime.monday), sunday18.addDays(1));
      expect(Week.onOrAfter(sunday18, DateTime.wednesday), sunday18.addDays(3));
      expect(Week.onOrAfter(sunday18, DateTime.saturday), sunday18.addDays(6));
    });

    test('never looks backwards, from any day of the week', () {
      for (int offset = 0; offset < 7; offset++) {
        final CalendarDate from = sunday18.addDays(offset);
        for (int weekday = 1; weekday <= 7; weekday++) {
          final CalendarDate found = Week.onOrAfter(from, weekday);
          expect(found.weekday, weekday);
          expect(found.isOnOrAfter(from), isTrue);
          expect(from.daysUntil(found), lessThan(7));
        }
      }
    });

    test('rejects a weekday outside 1..7', () {
      expect(() => Week.onOrAfter(sunday18, 0), throwsArgumentError);
      expect(() => Week.onOrAfter(sunday18, 8), throwsArgumentError);
    });
  });

  group('Week.between', () {
    test('counts whole weeks', () {
      final CalendarDate from = CalendarDate(2026, 10, 18);
      expect(Week.between(from, from), 0);
      expect(Week.between(from, from.addDays(7)), 1);
      expect(Week.between(from, from.addDays(70)), 10);
    });
  });
}
