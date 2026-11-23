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

  /// Whether this is "yours starts" or "yours ends, tell the next person".
  bool get isHandover => id > ReminderPlan.handoverOffset;

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
  /// How many of this member's turns to plan for.
  static const int horizon = 8;

  /// Keeps a handover reminder's id clear of a turn reminder's.
  ///
  /// Ids are derived from a date, so the largest one a calendar can produce
  /// is 99991231. Offsetting by this leaves both kinds distinct and both
  /// inside a 32-bit int, which is what a notification id has to be.
  static const int handoverOffset = 500000000;

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
    int mine = 0;

    for (final Turn turn in engine.turnsFrom(today, count: horizon * 12)) {
      if (turn.leader.id != youAre) {
        continue;
      }

      final CalendarDate eveningBefore = turn.weekStart.subtractDays(1);
      final DateTime at = _at(eveningBefore, timeOfDay);

      // Counted here rather than per turn, because the horizon has always
      // meant "this many reminders actually scheduled": a turn whose
      // evening has already gone must not consume one of them. Moving this
      // line broke the test that says so.
      if (at.isAfter(now)) {
        mine++;
        reminders.add(
          Reminder(
            id: _idFor(turn.weekStart),
            at: at,
            title: 'Your week starts tomorrow',
            body: 'You are leading family prayer from tomorrow.',
            turnStarts: turn.weekStart,
          ),
        );
      }

      // And the other end of the same week.
      //
      // #77 wanted a reminder that reaches everybody, and the free tier has
      // nowhere to send one from (ADR-010). This reaches the one phone that
      // is certainly engaged — the person who has been leading all week —
      // and asks them to pass it on, which is how the family handed over
      // before there was an app.
      final Reminder? handover = _handover(
        engine: engine,
        myTurn: turn,
        timeOfDay: timeOfDay,
        now: now,
      );
      if (handover != null) {
        reminders.add(handover);
      }

      if (mine == horizon) {
        break;
      }
    }

    reminders.sort((Reminder a, Reminder b) => a.at.compareTo(b.at));
    return reminders;
  }

  /// "Your week ends tomorrow, and whoever is next is named."
  ///
  /// Null when there is no next turn to hand over to, or when the evening
  /// has already passed.
  static Reminder? _handover({
    required RotaEngine engine,
    required Turn myTurn,
    required Duration timeOfDay,
    required DateTime now,
  }) {
    final CalendarDate handsOverOn = myTurn.weekEnd.addDays(1);
    final Turn? next = engine.turnOn(handsOverOn);
    if (next == null || next.leader.id == myTurn.leader.id) {
      return null;
    }

    final DateTime at = _at(myTurn.weekEnd, timeOfDay);
    if (!at.isAfter(now)) {
      return null;
    }

    return Reminder(
      id: _idFor(handsOverOn) + handoverOffset,
      at: at,
      title: 'Your week ends tomorrow',
      body:
          '${next.leader.displayName} leads family prayer from tomorrow. '
          'Worth telling them.',
      turnStarts: handsOverOn,
    );
  }

  static DateTime _at(CalendarDate date, Duration timeOfDay) =>
      DateTime(date.year, date.month, date.day).add(timeOfDay);

  /// A small, stable number for a date.
  static int _idFor(CalendarDate weekStart) =>
      weekStart.year * 10000 + weekStart.month * 100 + weekStart.day;
}
