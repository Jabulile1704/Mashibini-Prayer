import '../../../domain/reminders/reminder_plan.dart';

/// Delivering reminders, whatever is underneath.
abstract interface class Reminders {
  /// Asks the person for permission, returning whether it was given.
  Future<bool> requestPermission();

  /// Replaces every pending reminder with [reminders].
  Future<void> schedule(List<Reminder> reminders);

  /// Removes everything pending. Used when reminders are switched off.
  Future<void> cancelAll();

  /// What is currently scheduled, by id. For tests and for diagnosing a
  /// phone that is not ringing when it should.
  Future<Set<int>> pending();
}
