import 'package:mashibini_prayer/src/data/sources/notifications/reminders.dart';
import 'package:mashibini_prayer/src/domain/reminders/reminder_plan.dart';

/// Reminders that do not ring.
class FakeReminders implements Reminders {
  List<Reminder> scheduled = <Reminder>[];
  int cancelCount = 0;
  int permissionRequests = 0;

  /// What the phone says when asked. Set false to test a refusal.
  bool permissionGranted = true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    scheduled = List<Reminder>.of(reminders);
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
    scheduled = <Reminder>[];
  }

  @override
  Future<Set<int>> pending() async => <int>{
    for (final Reminder reminder in scheduled) reminder.id,
  };
}
