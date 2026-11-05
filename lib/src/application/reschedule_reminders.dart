import '../data/repositories/device_settings_repository.dart';
import '../data/repositories/family_repository.dart';
import '../data/sources/notifications/reminders.dart';
import '../domain/entities/calendar_date.dart';
import '../domain/entities/family.dart';
import '../domain/reminders/reminder_plan.dart';

/// Brings this phone's pending reminders back into line with what is stored.
///
/// The first inhabitant of a layer `ARCHITECTURE.md` has described since Day 1
/// and that nothing had ever been put in. It is here rather than on a screen
/// because two screens now need it and a third will: anything that changes who
/// is in the rota, which weeks are theirs, or which member this phone belongs
/// to leaves the pending notifications describing a rota that no longer
/// exists.
///
/// That failure is silent. The app looks right, and the phone rings on the
/// wrong evening weeks later, which nobody reports as a bug — they just stop
/// believing it. So the rule is: **every write that can change whose week it
/// is calls this afterwards.**
///
/// It reads what is stored rather than taking a [Family] argument, so it
/// cannot be handed a copy that a dialog closed over before the save.
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
  ///
  /// Does nothing at all while reminders are switched off. A phone that has
  /// not been asked for permission sends nothing (R5.1), and scheduling
  /// against a switch that is off would be holding notifications somebody
  /// declined.
  Future<void> call({
    required CalendarDate today,
    required DateTime now,
  }) async {
    if (!await settings.loadRemindersEnabled()) {
      return;
    }

    final Family? family = await families.load();
    final String? youAre = await settings.loadYouAre();

    // Nobody to remind, or nothing to remind them about. Cancelling rather
    // than returning: whatever is pending was planned for a rota or a person
    // that is gone.
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
