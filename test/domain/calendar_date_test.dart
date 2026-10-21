import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';

void main() {
  group('CalendarDate', () {
    test('prints as ISO yyyy-mm-dd, zero padded', () {
      expect(CalendarDate(2026, 1, 5).toString(), '2026-01-05');
      expect(CalendarDate(2026, 10, 18).toString(), '2026-10-18');
    });

    test('parses the form the database stores', () {
      expect(CalendarDate.parse('2026-10-18'), CalendarDate(2026, 10, 18));
    });

    test('refuses anything that is not a bare date', () {
      expect(
        () => CalendarDate.parse('2026-10-18T00:00:00Z'),
        throwsFormatException,
      );
      expect(() => CalendarDate.parse('18/10/2026'), throwsFormatException);
      expect(() => CalendarDate.parse('2026-10-5'), throwsFormatException);
    });

    test('refuses a date that does not exist rather than rolling it over', () {
      expect(() => CalendarDate.parse('2026-02-31'), throwsFormatException);
      expect(() => CalendarDate.parse('2026-13-01'), throwsFormatException);
    });

    test('knows the ISO weekday', () {
      // 18 October 2026 is a Sunday.
      expect(CalendarDate(2026, 10, 18).weekday, DateTime.sunday);
      expect(CalendarDate(2026, 10, 19).weekday, DateTime.monday);
    });

    test('adds and subtracts days across a month boundary', () {
      expect(CalendarDate(2026, 10, 31).addDays(1), CalendarDate(2026, 11, 1));
      expect(
        CalendarDate(2026, 1, 1).subtractDays(1),
        CalendarDate(2025, 12, 31),
      );
    });

    test('counts whole days, signed', () {
      expect(
        CalendarDate(2026, 10, 18).daysUntil(CalendarDate(2026, 10, 25)),
        7,
      );
      expect(
        CalendarDate(2026, 10, 25).daysUntil(CalendarDate(2026, 10, 18)),
        -7,
      );
    });

    test('crosses a leap day correctly', () {
      expect(CalendarDate(2028, 2, 28).addDays(1), CalendarDate(2028, 2, 29));
      expect(CalendarDate(2028, 2, 28).daysUntil(CalendarDate(2028, 3, 1)), 2);
      // 2027 is not a leap year.
      expect(CalendarDate(2027, 2, 28).daysUntil(CalendarDate(2027, 3, 1)), 1);
    });

    test('day arithmetic is unaffected by a southern-hemisphere DST date', () {
      // South Africa has no DST, but the type must not depend on that: these
      // are dates where many timezones shift. A date type that secretly held
      // a local instant could lose or gain a day here.
      final CalendarDate beforeShift = CalendarDate(2026, 3, 29);
      expect(beforeShift.addDays(1), CalendarDate(2026, 3, 30));
      expect(CalendarDate(2026, 10, 25).addDays(1), CalendarDate(2026, 10, 26));
    });

    test('compares and sorts', () {
      final List<CalendarDate> dates = <CalendarDate>[
        CalendarDate(2026, 12, 1),
        CalendarDate(2026, 1, 1),
        CalendarDate(2026, 6, 1),
      ]..sort();
      expect(dates.map((CalendarDate d) => d.month), <int>[1, 6, 12]);
      expect(
        CalendarDate(2026, 1, 1).isBefore(CalendarDate(2026, 1, 2)),
        isTrue,
      );
      expect(
        CalendarDate(2026, 1, 1).isOnOrBefore(CalendarDate(2026, 1, 1)),
        isTrue,
      );
    });

    test('equal dates are equal values', () {
      expect(CalendarDate(2026, 10, 18), CalendarDate(2026, 10, 18));
      expect(
        CalendarDate(2026, 10, 18).hashCode,
        CalendarDate(2026, 10, 18).hashCode,
      );
    });
  });
}
