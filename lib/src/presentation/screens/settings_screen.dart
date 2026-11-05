import 'package:flutter/material.dart';

import '../../application/reschedule_reminders.dart';
import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../data/sources/platform/app_version.dart';
import '../../data/sources/platform/sharing.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/turn.dart';
import '../../domain/ids.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/journal/journal_export.dart';
import '../../domain/reminders/reminder_plan.dart';
import '../../domain/rota/family_editor.dart';
import '../../domain/rota/rota_engine.dart';
import '../../domain/rota/week.dart';
import '../brand/tokens.dart';
import '../widgets/date_text.dart';
import '../widgets/weekday_names.dart';
import 'about_screen.dart';
import 'family_members_screen.dart';
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
/// - *The turnover day* could not be changed without rebuilding the rota.
///   Day 19 shipped it as a read-only row with the reason written down
///   rather than shrugged at (ADR-019); Day 20 built the epoch machinery it
///   needed; it is a real row now (#100).
/// - *Who takes a week* had no route at all. `FamilyEditor` could add and
///   remove people and nothing called it, so the only way to change the
///   family was to throw the rota away (#74).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.familyRepository,
    required this.settings,
    required this.journal,
    required this.sharing,
    required this.reminders,
    required this.appVersion,
    required this.ids,
    this.today,
    this.now,
    super.key,
  });

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settings;
  final JournalRepository journal;
  final Sharing sharing;
  final Reminders reminders;
  final AppVersion appVersion;
  final IdGenerator ids;
  final CalendarDate Function()? today;
  final DateTime Function()? now;

  static const Key youAreRow = Key('settings.youAre');
  static const Key remindersRow = Key('settings.reminders');
  static const Key appearanceRow = Key('settings.appearance');
  static const Key turnoverRow = Key('settings.turnover');
  static const Key membersRow = Key('settings.members');
  static const Key confirmTurnover = Key('settings.turnover.confirm');
  static const Key startAgainRow = Key('settings.startAgain');
  static const Key exportRow = Key('settings.export');
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
  /// Moved into `application/` once a second screen needed it (#74). It used
  /// to be a method here, which was fine while there was one screen that
  /// could change the rota and is the usual way two copies start to differ.
  Future<void> _reschedule() => RescheduleReminders(
    families: widget.familyRepository,
    settings: widget.settings,
    reminders: widget.reminders,
  )(today: _today, now: _now);

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

  // ─────────────────────────────── the journal ─────────────────────────────

  /// Hands the whole journal to the phone's share sheet, as plain text.
  ///
  /// This exists because a reinstall takes the journal with it (#104), and
  /// on iOS a reinstall happens roughly weekly whether anybody wants one or
  /// not. Sync would not help: journal entries are deliberately outside the
  /// family tree (ADR-004), so they are not what #75 would be syncing.
  ///
  /// Everything about *what the document says* lives in `JournalExport` and
  /// is tested without a share sheet. This is the part that cannot be.
  Future<void> _exportJournal() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    final List<JournalEntry> entries = await widget.journal.all();
    if (!mounted) {
      return;
    }

    final String document = JournalExport.asText(
      entries,
      formatDate: (CalendarDate date) => DateLabels.full(context, date),
      savedOn: _today,
    );

    try {
      await widget.sharing.shareText(
        text: document,
        subject: JournalExport.subject(DateLabels.full(context, _today)),
      );
    } on Object catch (error) {
      // A share sheet that will not open is not a reason to lose the
      // screen. Said out loud rather than swallowed, because somebody
      // exporting a journal is doing it for a reason.
      if (mounted) {
        setState(() => _message = 'Your phone could not share it: $error');
      }
    }

    if (mounted) {
      setState(() => _busy = false);
    }
  }

  // ───────────────────────────── the turnover day ──────────────────────────

  /// Moves the day the week turns over on (#100).
  ///
  /// The confirmation is built from the change itself rather than from a
  /// description of it. `changeTurnoverDay` returns the family that would be
  /// saved; this reads the date, the short week and its leader off *that*,
  /// and saves the same object if the family agrees. So the dialog cannot
  /// promise one thing and the store do another.
  ///
  /// It has three sentences and needs all three. Moving the day is the only
  /// edit in the app with a consequence nobody would guess: the week before
  /// the change is one to six days short, because the calendar does not
  /// divide (ADR-019). Hiding that would be a pleasant dialog and a confusing
  /// Sunday.
  Future<void> _chooseTurnoverDay(Family family) async {
    final int? chosen = await _pick<int>(
      title: 'The week turns over on',
      explanation:
          'The day the rota changes hands. Weeks that have already happened '
          'are never re-cut, so nobody loses a turn they have led.',
      options: <_Option<int>>[
        for (final MapEntry<int, String> day
            in WeekdayNames.byIsoWeekday.entries)
          _Option<int>(value: day.key, label: day.value),
      ],
      selected: family.turnoverWeekday,
    );
    if (chosen == null || chosen == family.turnoverWeekday || !mounted) {
      return;
    }

    final Family after;
    try {
      after = FamilyEditor.changeTurnoverDay(
        family,
        weekday: chosen,
        today: _today,
        ids: widget.ids,
      );
    } on ArgumentError catch (error) {
      setState(() => _message = error.message.toString());
      return;
    }

    final RotaEngine engine = RotaEngine.forFamily(after);
    final CalendarDate from = after.latestCycle.effectiveFrom;
    final Turn? shortened = engine.turnOn(from.subtractDays(1));
    final Turn? first = engine.turnOn(from);
    if (!mounted) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Hand over on ${WeekdayNames.byIsoWeekday[chosen]}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('From ${DateLabels.full(context, from)}.'),
            if (shortened != null) ...<Widget>[
              const SizedBox(height: Space.md),
              Text(
                '${shortened.leader.displayName} has the week before that, '
                'and it will be ${_lengthInDays(shortened)} instead of '
                'seven — the first ${WeekdayNames.byIsoWeekday[chosen]} '
                'arrives before their week would have ended.',
              ),
            ],
            if (first != null) ...<Widget>[
              const SizedBox(height: Space.md),
              Text('${first.leader.displayName} takes the first full week.'),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Leave it'),
          ),
          TextButton(
            key: SettingsScreen.confirmTurnover,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change it'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    // The family the dialog described, not one computed again afterwards.
    await widget.familyRepository.save(after);
    await _reschedule();
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  static String _lengthInDays(Turn turn) {
    final int days = turn.weekStart.daysUntil(turn.weekEnd) + 1;
    return days == 1 ? 'one day' : '$days days';
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

      const _Heading('Your journal'),
      ListTile(
        key: SettingsScreen.exportRow,
        title: const Text('Keep a copy of my journal'),
        subtitle: const Text(
          'Sends it to yourself as plain text. Nothing else leaves this '
          'phone, and reinstalling the app loses what is not kept.',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.ios_share),
        onTap: _busy ? null : _exportJournal,
      ),

      const _Heading('The rota'),
      ListTile(
        key: SettingsScreen.membersRow,
        title: const Text('Who takes a week'),
        subtitle: Text(_membersSummary(family)),
        trailing: const Icon(Icons.chevron_right),
        onTap: family == null || _busy ? null : () => _openMembers(),
      ),
      ListTile(
        key: SettingsScreen.turnoverRow,
        title: const Text('The week turns over on'),
        subtitle: Text(_turnoverName(family)),
        trailing: const Icon(Icons.chevron_right),
        // Read-only on Day 19, for a reason that was written down rather
        // than shrugged at: the day was one field on the family, and moving
        // it re-cut every week the rota had ever had (ADR-019). Day 20 made
        // it an epoch, so there is a route now.
        onTap: family == null || _busy
            ? null
            : () => _chooseTurnoverDay(family),
      ),
      ListTile(
        key: SettingsScreen.startAgainRow,
        title: const Text('Start the rota again'),
        subtitle: const Text('Replace everybody and start from scratch'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : _startAgain,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
        child: Text(
          'The two rows above change the rota without throwing it away. '
          'Starting again replaces the whole thing.',
          style: theme.textTheme.bodySmall,
        ),
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

  String _membersSummary(Family? family) {
    if (family == null) {
      return 'Set the rota up first';
    }
    final List<Member> members = FamilyEditor.activeMembers(family, _today);
    return members.map((Member member) => member.displayName).join(', ');
  }

  /// What day the week turns over on — and, if that is about to change, both
  /// answers.
  ///
  /// A change takes effect at a future turnover, so for a few days there are
  /// two true answers and `Family.turnoverWeekday` is the later one. A row
  /// showing only that would be telling somebody their week ends on a
  /// Wednesday while the app, correctly, ends it on the Sunday.
  String _turnoverName(Family? family) {
    if (family == null) {
      return 'Set the rota up first';
    }
    final int chosen = family.turnoverWeekday;
    final RotaEngine engine = RotaEngine.forFamily(family);
    final int inForce = engine.turnoverWeekdayOn(_today);
    if (inForce == chosen) {
      return '${WeekdayNames.byIsoWeekday[chosen]} — '
          'and it runs to the day before';
    }
    final CalendarDate from = Week.startOf(
      family.latestCycle.effectiveFrom,
      chosen,
    );
    return '${WeekdayNames.byIsoWeekday[inForce]} this week · '
        '${WeekdayNames.byIsoWeekday[chosen]} from '
        '${DateLabels.dayAndDate(context, from)}';
  }

  void _openMembers() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => FamilyMembersScreen(
          familyRepository: widget.familyRepository,
          settings: widget.settings,
          reminders: widget.reminders,
          ids: widget.ids,
          today: widget.today,
          now: widget.now,
        ),
      ),
    );
  }
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
