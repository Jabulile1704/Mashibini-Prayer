import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../data/sources/platform/app_version.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/ids.dart';
import '../../domain/reminders/reminder_plan.dart';
import '../../domain/rota/family_editor.dart';
import '../brand/tokens.dart';
import '../widgets/date_text.dart';
import '../widgets/weekday_names.dart';
import 'about_screen.dart';
import 'setup_screen.dart';

/// Where everything that has no other home now lives (ADR-016).
///
/// Day 18 created this screen and moved three things into it. Day 19 gives it
/// its actual contents, and the point of all four sections is the same one:
/// **a thing you can be asked once is a thing you can get wrong forever.**
///
/// - *Which one are you* was asked optionally during setup and then again on
///   the Reminders screen — but only while the answer was still missing. Pick
///   the wrong name and there was no screen in the app that would let you
///   change it. That is the defect this screen exists to fix.
/// - *Reminders* was a whole screen holding one switch, behind a chevron,
///   behind an unlabelled bell before that. It is two rows now.
/// - *Appearance* could not be chosen at all; the app followed the phone and
///   that was that.
/// - *The turnover day* is shown but not editable, and the reason is written
///   down rather than shrugged at: see ADR-019.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.familyRepository,
    required this.settings,
    required this.reminders,
    required this.appVersion,
    required this.ids,
    this.today,
    this.now,
    super.key,
  });

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settings;
  final Reminders reminders;
  final AppVersion appVersion;
  final IdGenerator ids;
  final CalendarDate Function()? today;
  final DateTime Function()? now;

  static const Key youAreRow = Key('settings.youAre');
  static const Key remindersRow = Key('settings.reminders');
  static const Key appearanceRow = Key('settings.appearance');
  static const Key turnoverRow = Key('settings.turnover');
  static const Key startAgainRow = Key('settings.startAgain');
  static const Key aboutRow = Key('settings.about');
  static const Key confirmStartAgain = Key('settings.startAgain.confirm');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Watched, not loaded once. This screen is a tab inside an `IndexedStack`,
  // so it is built on first use and never disposed — and one of its own rows
  // replaces the family outright. A `Future` taken at construction would go
  // stale the moment somebody started the rota again, and the row above it
  // would keep offering names from a family that no longer exists.
  late final Stream<Family?> _families = widget.familyRepository.watch();
  late final Stream<String?> _youAre = widget.settings.watchYouAre();
  late final Stream<bool> _remindersOn = widget.settings
      .watchRemindersEnabled();
  late final Stream<Appearance> _appearance = widget.settings.watchAppearance();

  /// True while a write is in flight, which disables the controls rather than
  /// letting two taps race each other to the store.
  bool _busy = false;

  /// Something the phone refused to do, said once rather than thrown away.
  String? _message;

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  // ───────────────────────── which one are you ─────────────────────────

  /// Says which member is holding this phone.
  ///
  /// Reminders are the reason this has to be changeable. A phone that thinks
  /// it belongs to Mama rings for Mama's weeks, and until this row existed
  /// the only way to correct that was to rebuild the rota.
  Future<void> _chooseYouAre(Family family) async {
    final List<Member> members = FamilyEditor.activeMembers(family, _today);
    final String? current = await widget.settings.loadYouAre();
    if (!mounted) {
      return;
    }

    final String? chosen = await _pick<String>(
      title: 'Which one are you?',
      explanation:
          'This phone needs to know before it can tell you which weeks are '
          'yours. It is kept on this phone only.',
      options: <_Option<String>>[
        for (final Member member in members)
          _Option<String>(value: member.id, label: member.displayName),
      ],
      selected: current,
    );
    if (chosen == null || chosen == current) {
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    await widget.settings.saveYouAre(chosen);
    // Changing who you are changes which weeks ring. Saving without
    // re-planning would leave this phone holding somebody else's reminders,
    // which is the quiet kind of wrong that nobody reports as a bug.
    await _reschedule();
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  // ─────────────────────────────── reminders ───────────────────────────────

  Future<void> _setRemindersEnabled({required bool enabled}) async {
    setState(() {
      _busy = true;
      _message = null;
    });

    if (!enabled) {
      await widget.reminders.cancelAll();
      await widget.settings.saveRemindersEnabled(enabled: false);
      if (mounted) {
        setState(() => _busy = false);
      }
      return;
    }

    final bool allowed = await widget.reminders.requestPermission();
    if (!allowed) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message =
              'Your phone did not allow notifications. You can turn them on '
              'for this app in your phone settings.';
        });
      }
      return;
    }

    await widget.settings.saveRemindersEnabled(enabled: true);
    await _reschedule();
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  /// Re-plans this phone's reminders from whatever is stored now.
  ///
  /// Reads the family rather than closing over one, so it cannot act on a
  /// stale copy. Does nothing when reminders are off — a phone that has not
  /// been asked sends nothing (R5.1).
  Future<void> _reschedule() async {
    if (!await widget.settings.loadRemindersEnabled()) {
      return;
    }
    final Family? family = await widget.familyRepository.load();
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

  /// The next reminder this phone is holding, as a sentence.
  ///
  /// The Reminders screen listed three. One is enough to answer the question
  /// it was really there to answer — *does it agree with me about whose week
  /// is next* — and it fits under the switch instead of needing a screen.
  String _nextReminder(Family? family, String? youAre) {
    if (youAre == null) {
      return 'Say which one you are first';
    }
    if (family == null) {
      return 'Nothing to remind you about yet';
    }
    final List<Reminder> next = ReminderPlan.forDevice(
      family: family,
      youAre: youAre,
      today: _today,
      now: _now,
      horizon: 1,
    );
    if (next.isEmpty) {
      return 'Nothing to remind you about yet';
    }
    return 'Next: the evening before '
        '${DateLabels.dayAndDate(context, next.first.turnStarts)}';
  }

  // ─────────────────────────────── appearance ──────────────────────────────

  Future<void> _chooseAppearance(Appearance current) async {
    final Appearance? chosen = await _pick<Appearance>(
      title: 'Appearance',
      explanation:
          'The bee colours are the same in all three — honey is brightest '
          'against the dark and deepens against the cream, so it stays '
          'readable either way.',
      options: const <_Option<Appearance>>[
        _Option<Appearance>(
          value: Appearance.system,
          label: 'Follow the phone',
        ),
        _Option<Appearance>(value: Appearance.light, label: 'Light'),
        _Option<Appearance>(value: Appearance.dark, label: 'Dark'),
      ],
      selected: current,
    );
    if (chosen == null || chosen == current) {
      return;
    }
    await widget.settings.saveAppearance(chosen);
  }

  // ─────────────────────────────── the rota ────────────────────────────────

  /// Starts the rota over, after asking.
  ///
  /// It replaces the family, so it asks. The journal is kept and the dialog
  /// says so: it is stored separately and has nothing to do with the cycle.
  Future<void> _startAgain() async {
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

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SetupScreen(
          familyRepository: widget.familyRepository,
          settingsRepository: widget.settings,
          ids: widget.ids,
          today: widget.today,
        ),
      ),
    );
    // A new rota means new weeks, and this phone may now be holding
    // reminders for dates that belong to somebody else.
    await _reschedule();
  }

  // ──────────────────────────────── the list ───────────────────────────────

  /// One choice from a list, or null if it was dismissed.
  ///
  /// Deliberately not `RadioListTile`: a tick on the chosen row says the same
  /// thing, closes on one tap rather than two, and has no fixed-width control
  /// to collide with a long name at the largest text size.
  Future<T?> _pick<T extends Object>({
    required String title,
    required String explanation,
    required List<_Option<T>> options,
    required T? selected,
  }) => showDialog<T>(
    context: context,
    builder: (BuildContext context) {
      final ThemeData theme = Theme.of(context);
      return AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.only(top: Space.md, bottom: Space.sm),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.xl,
                  0,
                  Space.xl,
                  Space.md,
                ),
                child: Text(explanation, style: theme.textTheme.bodySmall),
              ),
              for (final _Option<T> option in options)
                ListTile(
                  title: Text(option.label),
                  trailing: option.value == selected
                      ? Icon(Icons.check, color: theme.colorScheme.secondary)
                      : null,
                  onTap: () => Navigator.of(context).pop(option.value),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: StreamBuilder<Family?>(
          stream: _families,
          builder: (BuildContext context, AsyncSnapshot<Family?> stored) {
            final Family? family = stored.data;

            return StreamBuilder<String?>(
              stream: _youAre,
              builder: (BuildContext context, AsyncSnapshot<String?> who) {
                final String? youAre = who.data;

                return StreamBuilder<bool>(
                  stream: _remindersOn,
                  builder: (BuildContext context, AsyncSnapshot<bool> on) {
                    final bool remindersOn = on.data ?? false;

                    return StreamBuilder<Appearance>(
                      stream: _appearance,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<Appearance> look,
                          ) => ListView(
                            padding: const EdgeInsets.only(bottom: Space.xxl),
                            children: _rows(
                              theme: theme,
                              family: family,
                              youAre: youAre,
                              remindersOn: remindersOn,
                              appearance: look.data ?? Appearance.system,
                            ),
                          ),
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

  List<Widget> _rows({
    required ThemeData theme,
    required Family? family,
    required String? youAre,
    required bool remindersOn,
    required Appearance appearance,
  }) {
    return <Widget>[
      const _Heading('This phone'),
      ListTile(
        key: SettingsScreen.youAreRow,
        title: const Text('Which one are you?'),
        subtitle: Text(_youAreName(family, youAre)),
        trailing: const Icon(Icons.chevron_right),
        // Nothing to choose from until a rota exists. Disabled rather than
        // hidden: a row that appears later is harder to find than one that
        // was always there.
        onTap: family == null || _busy ? null : () => _chooseYouAre(family),
      ),
      ListTile(
        key: SettingsScreen.appearanceRow,
        title: const Text('Appearance'),
        subtitle: Text(_appearanceName(appearance)),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : () => _chooseAppearance(appearance),
      ),

      const _Heading('Reminders'),
      SwitchListTile(
        key: SettingsScreen.remindersRow,
        value: remindersOn,
        onChanged: _busy
            ? null
            : (bool to) => _setRemindersEnabled(enabled: to),
        title: const Text('Remind me before my week'),
        subtitle: Text(
          remindersOn
              ? _nextReminder(family, youAre)
              : 'The evening before your turn starts',
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
        child: Text(
          'This phone reminds you, and only you. The app cannot send '
          'anything to anyone else\'s phone.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.sm,
          ),
          child: Text(
            _message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),

      const _Heading('The rota'),
      ListTile(
        key: SettingsScreen.turnoverRow,
        title: const Text('The week turns over on'),
        subtitle: Text(_turnoverName(family)),
        // No `onTap`, and deliberately **not** `enabled: false`. Changing
        // the turnover day moves every week boundary the rota has ever had,
        // and the engine refuses a family whose cycles no longer start on it
        // — so this is a new epoch, not a setting (ADR-019, #100). Until
        // then the row below is the honest route and says what it replaces.
        //
        // Disabling it was the first attempt and it was wrong twice. This is
        // a fact, not a dead control; and `disabledColor` is 38% opacity,
        // which composites to **2.42:1** against the wax ground — a row
        // stating something you cannot read.
      ),
      ListTile(
        key: SettingsScreen.startAgainRow,
        title: const Text('Start the rota again'),
        subtitle: const Text(
          'Change who takes a week, the order, or the turnover day',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : _startAgain,
      ),

      const _Heading('About'),
      ListTile(
        key: SettingsScreen.aboutRow,
        title: const Text('About Mashibini Prayer'),
        subtitle: FutureBuilder<String>(
          future: widget.appVersion.describe(),
          builder: (BuildContext context, AsyncSnapshot<String> version) =>
              Text(
                version.data == null
                    ? 'What it does, and what it does not'
                    : 'Version ${version.data}',
              ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                AboutScreen(appVersion: widget.appVersion),
          ),
        ),
      ),
    ];
  }

  String _youAreName(Family? family, String? youAre) {
    if (family == null) {
      return 'Set the rota up first';
    }
    if (youAre == null) {
      return 'Nobody has said yet';
    }
    final Member? member = family.membersById[youAre];
    // A name that is stored but no longer in the family: possible after a
    // member is removed, and better said plainly than rendered as a blank.
    return member?.displayName ?? 'Somebody who has left the rota';
  }

  String _appearanceName(Appearance appearance) => switch (appearance) {
    Appearance.system => 'Follow the phone',
    Appearance.light => 'Light',
    Appearance.dark => 'Dark',
  };

  String _turnoverName(Family? family) => family == null
      ? 'Set the rota up first'
      : '${WeekdayNames.byIsoWeekday[family.turnoverWeekday]} — '
            'and it runs to the day before';
}

class _Option<T extends Object> {
  const _Option({required this.value, required this.label});

  final T value;
  final String label;
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
