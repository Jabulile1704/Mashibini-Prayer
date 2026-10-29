import 'package:mashibini_prayer/src/data/sources/notifications/reminders.dart';
import 'package:mashibini_prayer/src/domain/reminders/reminder_plan.dart';

/// Reminders that do not ring.
///
/// The interesting rules all live in `ReminderPlan`, which is pure. This
/// stands in for the part that talks to the operating system, so the opt-in
/// behaviour can be tested without a device that can make a noise — and so a
/// test can assert that nothing was scheduled, which is the half of R5.1 that
/// matters most.
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
