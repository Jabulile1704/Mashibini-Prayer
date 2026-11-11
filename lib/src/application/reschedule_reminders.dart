import '../data/repositories/device_settings_repository.dart';
import '../data/repositories/family_repository.dart';
import '../data/sources/notifications/reminders.dart';
import '../domain/entities/calendar_date.dart';
import '../domain/entities/family.dart';
import '../domain/reminders/reminder_plan.dart';

/// Brings this phone's pending reminders back into line with what is stored.
class RescheduleReminders {
  const RescheduleReminders({
    required this.families,
    required this.settings,
    required this.reminders,
  });

  final FamilyRepository families;
  final DeviceSettingsRepository settings;
  final Reminders reminders;

  /// Re-plans from the stored family, as of [today].
  Future<void> call({
    required CalendarDate today,
    required DateTime now,
  }) async {
    if (!await settings.loadRemindersEnabled()) {
      return;
    }

    final Family? family = await families.load();
    final String? youAre = await settings.loadYouAre();

    if (family == null || youAre == null) {
      await reminders.cancelAll();
      return;
    }

    await reminders.schedule(
      ReminderPlan.forDevice(
        family: family,
        youAre: youAre,
        today: today,
        now: now,
      ),
    );
  }
}
