import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../data/sources/platform/app_version.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/ids.dart';
import '../brand/tokens.dart';
import 'reminders_screen.dart';
import 'setup_screen.dart';

/// Where everything that has no other home now lives (ADR-016).
///
/// Day 18 does not invent this screen's contents. It **relocates** them:
/// the reminders switch that was a whole screen behind an unlabelled bell,
/// the "start the rota again" control that was bolted into the app bar on
/// Day 17, and the version line that went at the foot of This Week on Day 14
/// only because there was nowhere else to put it.
///
/// Day 19 adds what is still missing — which one are you, the turnover day,
/// appearance — and #74's family editor. This screen exists first so those
/// have somewhere to arrive.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.familyRepository,
    required this.settings,
    required this.reminders,
    required this.appVersion,
    required this.ids,
    this.today,
    super.key,
  });

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settings;
  final Reminders reminders;
  final AppVersion appVersion;
  final IdGenerator ids;
  final CalendarDate Function()? today;

  static const Key remindersRow = Key('settings.reminders');
  static const Key startAgainRow = Key('settings.startAgain');
  static const Key confirmStartAgain = Key('settings.startAgain.confirm');

  Future<void> _openReminders(BuildContext context) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => RemindersScreen(
            familyRepository: familyRepository,
            settings: settings,
            reminders: reminders,
            today: today,
          ),
        ),
      );

  /// Starts the rota over, after asking.
  ///
  /// It replaces the family, so it asks. The journal is kept and the dialog
  /// says so: it is stored separately and has nothing to do with the cycle.
  Future<void> _startAgain(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Start the rota again?'),
        content: const Text(
          'This replaces who takes a week, the order, and the day the week '
          'turns over. Your journal is kept.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: SettingsScreen.confirmStartAgain,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start again'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !context.mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SetupScreen(
          familyRepository: familyRepository,
          settingsRepository: settings,
          ids: ids,
          today: today,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          children: <Widget>[
            _Heading('Reminders'),
            ListTile(
              key: SettingsScreen.remindersRow,
              title: const Text('Remind me before my week'),
              subtitle: const Text('The evening before your turn starts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openReminders(context),
            ),

            _Heading('The rota'),
            ListTile(
              key: SettingsScreen.startAgainRow,
              title: const Text('Start the rota again'),
              subtitle: const Text(
                'Change who takes a week, the order, or the turnover day',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _startAgain(context),
            ),

            const SizedBox(height: Space.xxl),
            Center(
              child: FutureBuilder<String>(
                future: appVersion.describe(),
                builder: (BuildContext context, AsyncSnapshot<String> version) {
                  final String? value = version.data;
                  if (value == null) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    'Version $value',
                    style: theme.textTheme.bodySmall,
                  );
                },
              ),
            ),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.sm),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge,
    ),
  );
}
