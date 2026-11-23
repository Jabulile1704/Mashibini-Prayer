import 'dart:async';

import '../data/repositories/device_settings_repository.dart';
import '../data/repositories/family_repository.dart';
import '../data/sources/notifications/reminders.dart';
import '../domain/entities/calendar_date.dart';
import '../domain/entities/family.dart';
import 'reschedule_reminders.dart';

/// Keeps this phone's reminders in step with the rota it now holds (#160).
///
/// Until Day 32 the only way a family could change was somebody editing it
/// on this phone, so the screens that edited it rescheduled and that was
/// enough. Sync means the rota changes while nobody is holding the phone,
/// and R5.1's first criterion stopped being true on every phone except the
/// one that made the change.
///
/// So the trigger is the stored family changing, which covers a merge
/// arriving, a reinstalled phone signing in, and a phone joining another
/// family — none of which involve a screen.
class KeepRemindersInStep {
  KeepRemindersInStep({
    required FamilyRepository families,
    required DeviceSettingsRepository settings,
    required Reminders reminders,
    DateTime Function()? now,
    this.onTrouble,
  }) : _families = families,
       _settings = settings,
       _now = now ?? DateTime.now,
       _reschedule = RescheduleReminders(
         families: families,
         settings: settings,
         reminders: reminders,
       );

  final FamilyRepository _families;
  final DeviceSettingsRepository _settings;
  final RescheduleReminders _reschedule;
  final DateTime Function() _now;

  /// Told when a reminder could not be scheduled. Never thrown.
  final void Function(Object error, StackTrace stack)? onTrouble;

  // Cancelled in `dispose`. The lint only looks inside the function that
  // creates it.
  // ignore: cancel_subscriptions
  final List<StreamSubscription<Object?>> _watching =
      <StreamSubscription<Object?>>[];

  /// Starts following the two things a plan depends on.
  ///
  /// The screens that change either of these reschedule as well, inside
  /// their own progress indicator, so the person sees it happen. That is
  /// for immediacy. This is the guarantee, and it is the only one that
  /// covers a change nobody on this phone made.
  void start() {
    if (_watching.isNotEmpty) {
      return;
    }
    _watching.add(
      _families.watch().listen(
        (Family? _) => unawaited(_replan()),
        onError: (Object error, StackTrace stack) =>
            onTrouble?.call(error, stack),
      ),
    );
    _watching.add(
      _settings.watchYouAre().listen(
        (String? _) => unawaited(_replan()),
        onError: (Object error, StackTrace stack) =>
            onTrouble?.call(error, stack),
      ),
    );
  }

  /// Re-plans now, whatever the stored family has become.
  Future<void> replanNow() => _replan();

  Future<void> _replan() async {
    final DateTime now = _now();
    try {
      await _reschedule(today: CalendarDate.from(now), now: now);
    } on Object catch (error, stack) {
      // A phone that will not schedule a notification is not a reason to
      // stop syncing, and the rota is still correct on screen.
      onTrouble?.call(error, stack);
    }
  }

  Future<void> dispose() async {
    final List<StreamSubscription<Object?>> watching =
        List<StreamSubscription<Object?>>.of(_watching);
    _watching.clear();
    for (final StreamSubscription<Object?> one in watching) {
      await one.cancel();
    }
  }
}
