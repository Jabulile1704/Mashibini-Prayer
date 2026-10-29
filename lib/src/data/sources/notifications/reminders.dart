import '../../../domain/reminders/reminder_plan.dart';

/// Delivering reminders, whatever is underneath.
///
/// An interface because everything interesting about reminders — which ones,
/// for whom, when — is decided by [ReminderPlan], which is pure. This is only
/// the part that talks to the operating system, and keeping it behind a seam
/// means the rules can be tested without a device that can ring.
abstract interface class Reminders {
  /// Asks the person for permission, returning whether it was given.
  ///
  /// Called only when somebody switches reminders on. An app that asks on
  /// first launch is asking before it has earned an answer.
  Future<bool> requestPermission();

  /// Replaces every pending reminder with [reminders].
  ///
  /// Replace rather than add: the plan is recomputed whenever the rota
  /// changes, and stale reminders for a week somebody no longer leads are
  /// worse than none.
  Future<void> schedule(List<Reminder> reminders);

  /// Removes everything pending. Used when reminders are switched off.
  Future<void> cancelAll();

  /// What is currently scheduled, by id. For tests and for diagnosing a
  /// phone that is not ringing when it should.
  Future<Set<int>> pending();
}
