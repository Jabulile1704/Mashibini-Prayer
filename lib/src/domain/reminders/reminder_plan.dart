import '../entities/calendar_date.dart';
import '../entities/family.dart';
import '../entities/member.dart';
import '../entities/turn.dart';
import '../rota/rota_engine.dart';

/// A reminder to be delivered at a moment.
class Reminder {
  const Reminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.turnStarts,
  });

  /// Stable across re-planning, so re-scheduling replaces rather than
  /// duplicates. Derived from the turn's date, which is the thing that makes
  /// one reminder different from another.
  final int id;

  final DateTime at;
  final String title;
  final String body;

  /// The turnover this is warning about.
  final CalendarDate turnStarts;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.turnStarts == turnStarts;

  @override
  int get hashCode => Object.hash(id, at, title, body, turnStarts);

  @override
  String toString() => 'Reminder($turnStarts, at $at)';
}

/// Works out which reminders this phone should be holding.
abstract final class ReminderPlan {
  /// How many turnovers ahead to plan for.
  static const int horizon = 8;

  /// The evening before, by default. Late enough to be the last thing in a
  /// day, early enough not to wake anybody.
  static const Duration defaultTimeOfDay = Duration(hours: 19);

  static List<Reminder> forDevice({
    required Family family,
    required String youAre,
    required CalendarDate today,
    required DateTime now,
    Duration timeOfDay = defaultTimeOfDay,
    int horizon = ReminderPlan.horizon,
  }) {
    final RotaEngine engine = RotaEngine.forFamily(family);
    final Member? me = family.membersById[youAre];
    if (me == null) {
      return const <Reminder>[];
    }

    final List<Reminder> reminders = <Reminder>[];

    for (final Turn turn in engine.turnsFrom(today, count: horizon * 12)) {
      if (turn.leader.id != youAre) {
        continue;
      }

      final CalendarDate eveningBefore = turn.weekStart.subtractDays(1);
      final DateTime at = _at(eveningBefore, timeOfDay);

      if (!at.isAfter(now)) {
        continue;
      }

      reminders.add(
        Reminder(
          id: _idFor(turn.weekStart),
          at: at,
          title: 'Your week starts tomorrow',
          body: 'You are leading family prayer from tomorrow.',
          turnStarts: turn.weekStart,
        ),
      );

      if (reminders.length == horizon) {
        break;
      }
    }

    return reminders;
  }

  static DateTime _at(CalendarDate date, Duration timeOfDay) =>
      DateTime(date.year, date.month, date.day).add(timeOfDay);

  /// A small, stable number for a date.
  static int _idFor(CalendarDate weekStart) =>
      weekStart.year * 10000 + weekStart.month * 100 + weekStart.day;
}
