import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/reminders/reminder_plan.dart';
import '../../domain/rota/family_editor.dart';
import '../widgets/date_text.dart';

/// Switching handover reminders on, and seeing what that means.
///
/// Off until asked. R5.1 says an install that has never been asked sends
/// nothing — an app that starts making noise uninvited is not a good
/// houseguest — so the switch starts off and the permission prompt only
/// appears when somebody reaches for it.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({
    required this.familyRepository,
    required this.settings,
    required this.reminders,
    this.today,
    this.now,
    super.key,
  });

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settings;
  final Reminders reminders;
  final CalendarDate Function()? today;
  final DateTime Function()? now;

  static const Key toggle = Key('reminders.toggle');
  static const Key youArePicker = Key('reminders.youAre');

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _busy = false;
  String? _message;

  // Built once. Reading a stream expression inside build() would hand the
  // builder a new subscription on every frame.
  late final Stream<bool> _enabled = widget.settings.watchRemindersEnabled();
  late final Stream<String?> _youAre = widget.settings.watchYouAre();
  late final Future<Family?> _family = widget.familyRepository.load();

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  Future<void> _setEnabled({required bool enabled}) async {
    setState(() {
      _busy = true;
      _message = null;
    });

    if (!enabled) {
      await widget.reminders.cancelAll();
      await widget.settings.saveRemindersEnabled(enabled: false);
      setState(() => _busy = false);
      return;
    }

    final bool allowed = await widget.reminders.requestPermission();
    if (!allowed) {
      setState(() {
        _busy = false;
        _message =
            'Your phone did not allow notifications. You can turn them on '
            'for this app in your phone settings.';
      });
      return;
    }

    await widget.settings.saveRemindersEnabled(enabled: true);
    await _reschedule();
    setState(() => _busy = false);
  }

  /// Says which member is holding this phone, then re-plans.
  ///
  /// Setup asks this as an optional question, and until reminders existed it
  /// only chose between "your week" and a name. It is now load-bearing: a
  /// phone that does not know whose it is cannot know which weeks to ring
  /// for. Asking again here — rather than sending somebody back through
  /// setup, which would rebuild the rota — is the whole reason this control
  /// exists.
  Future<void> _setYouAre(String memberId) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    await widget.settings.saveYouAre(memberId);
    if (await widget.settings.loadRemindersEnabled()) {
      await _reschedule();
    }
    setState(() => _busy = false);
  }

  Future<void> _reschedule() async {
    final Family? family = await _family;
    final String? youAre = await widget.settings.loadYouAre();
    if (family == null || youAre == null) {
      await widget.reminders.cancelAll();
      return;
    }
    await widget.reminders.schedule(
      ReminderPlan.forDevice(
        family: family,
        youAre: youAre,
        today: _today,
        now: _now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: SafeArea(
        child: FutureBuilder<Family?>(
          future: _family,
          builder: (BuildContext context, AsyncSnapshot<Family?> hasFamily) {
            final Family? family = hasFamily.data;

            return StreamBuilder<String?>(
              stream: _youAre,
              builder: (BuildContext context, AsyncSnapshot<String?> who) {
                final String? youAre = who.data;

                return StreamBuilder<bool>(
                  stream: _enabled,
                  builder: (BuildContext context, AsyncSnapshot<bool> on) {
                    final bool enabled = on.data ?? false;

                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: <Widget>[
                        if (family != null && youAre == null) ...<Widget>[
                          _WhichOneAreYou(
                            members: FamilyEditor.activeMembers(family, _today),
                            onChanged: _busy ? null : _setYouAre,
                          ),
                          const SizedBox(height: 28),
                        ],
                        SwitchListTile(
                          key: RemindersScreen.toggle,
                          value: enabled,
                          onChanged: _busy
                              ? null
                              : (bool value) => _setEnabled(enabled: value),
                          title: const Text('Remind me before my week'),
                          subtitle: const Text(
                            'The evening before your turn starts.',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This phone reminds you, and only you. The app '
                          'cannot send anything to anyone else\'s phone.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_message != null) ...<Widget>[
                          const SizedBox(height: 20),
                          Text(
                            _message!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                        if (enabled && youAre != null) ...<Widget>[
                          const SizedBox(height: 32),
                          Text('Coming up', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 12),
                          _Upcoming(
                            family: family,
                            youAre: youAre,
                            today: _today,
                            now: _now,
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The question setup asked optionally, asked again where it now matters.
class _WhichOneAreYou extends StatelessWidget {
  const _WhichOneAreYou({required this.members, required this.onChanged});

  final List<Member> members;
  final void Function(String memberId)? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Which one are you?', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'This phone needs to know before it can tell you which weeks are '
          'yours.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: RemindersScreen.youArePicker,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Choose your name',
          ),
          items: <DropdownMenuItem<String>>[
            for (final Member member in members)
              DropdownMenuItem<String>(
                value: member.id,
                child: Text(member.displayName),
              ),
          ],
          onChanged: onChanged == null
              ? null
              : (String? value) {
                  if (value != null) {
                    onChanged!(value);
                  }
                },
        ),
      ],
    );
  }
}

/// The reminders this phone is actually holding.
///
/// Shown because a reminder you cannot see is a reminder you cannot trust:
/// somebody who switches this on should be able to check it believes the
/// same thing they do about whose week is next.
class _Upcoming extends StatelessWidget {
  const _Upcoming({
    required this.family,
    required this.youAre,
    required this.today,
    required this.now,
  });

  final Family? family;
  final String youAre;
  final CalendarDate today;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Family? family = this.family;

    final List<Reminder> reminders = family == null
        ? const <Reminder>[]
        : ReminderPlan.forDevice(
            family: family,
            youAre: youAre,
            today: today,
            now: now,
            horizon: 3,
          );

    if (reminders.isEmpty) {
      return Text(
        'Nothing to remind you about yet. Your turns will appear here once '
        'the rota has one for you.',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final Reminder reminder in reminders)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Your week starting '
              '${DateLabels.dayAndDate(context, reminder.turnStarts)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
