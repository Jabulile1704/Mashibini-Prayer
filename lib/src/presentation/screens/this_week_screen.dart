import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../data/sources/platform/app_version.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/turn.dart';
import '../../domain/ids.dart';
import '../../domain/rota/rota_engine.dart';
import '../../data/sources/assets/bundled_verses.dart';
import '../../domain/verse/verse_for_the_day.dart';
import '../brand/mark.dart';
import '../widgets/centred_message.dart';
import '../widgets/date_text.dart';
import '../widgets/leading_card.dart';
import '../widgets/next_turn_tile.dart';
import '../widgets/verse_card.dart';
import 'journal_screen.dart';
import 'reminders_screen.dart';
import 'schedule_screen.dart';
import 'setup_screen.dart';

/// The home screen: whose week it is, who is next, and when it changes hands.
///
/// There are four things this screen can be looking at, and they are different
/// enough that conflating any two would mislead someone:
///
/// 1. still reading storage — briefly, on a cold start
/// 2. no family stored at all — first run, nothing set up yet
/// 3. a family whose rota has not started by today — set up, but ahead of time
/// 4. a turn to show
///
/// Two of those are a null, from different layers, and they mean opposite
/// things: "you have not set this up" versus "you set it up, it starts later".
class ThisWeekScreen extends StatefulWidget {
  const ThisWeekScreen({
    required this.repository,
    required this.settings,
    required this.journal,
    required this.reminders,
    required this.appVersion,
    required this.ids,
    this.today,
    super.key,
  });

  final FamilyRepository repository;

  /// Which member is holding this phone — recorded during setup, absent
  /// until somebody says.
  ///
  /// When it is absent the screen uses names. It never guesses, because being
  /// told someone else's turn is yours is worse than being told a name.
  final DeviceSettingsRepository settings;

  final JournalRepository journal;

  final Reminders reminders;

  /// Which build this is, shown quietly at the foot of the screen.
  final AppVersion appVersion;

  /// Passed through to setup, which mints ids for new members and cycles.
  final IdGenerator ids;

  /// The clock, injectable so a test can stand on any date.
  ///
  /// The domain refuses to read a clock (ADR-002); this is the boundary where
  /// one is finally read, and it is a parameter rather than a call so the
  /// screen is testable on any week of the next decade.
  final CalendarDate Function()? today;

  static const Key scheduleButton = Key('home.schedule');

  @override
  State<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends State<ThisWeekScreen> {
  late final Stream<Family?> _families = widget.repository.watch();
  late final Stream<String?> _youAre = widget.settings.watchYouAre();
  late final Future<VerseForTheDay> _verses = BundledVerses.load();

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  Future<void> _openReminders() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RemindersScreen(
          familyRepository: widget.repository,
          settings: widget.settings,
          reminders: widget.reminders,
          today: widget.today,
        ),
      ),
    );
  }

  Future<void> _openSchedule() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ScheduleScreen(
          familyRepository: widget.repository,
          settings: widget.settings,
          ids: widget.ids,
          today: widget.today,
        ),
      ),
    );
  }

  Future<void> _openJournal() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            JournalScreen(journal: widget.journal, today: widget.today),
      ),
    );
  }

  Future<void> _openSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SetupScreen(
          familyRepository: widget.repository,
          settingsRepository: widget.settings,
          ids: widget.ids,
          today: widget.today,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mashibini Prayer'),
        actions: <Widget>[
          // Label *and* tooltip on each. A tooltip alone reaches the
          // semantics tree as a tooltip, not a label, which leaves an
          // icon-only button announcing as "button" with the name as an
          // afterthought. The label is what a screen reader leads with.
          IconButton(
            key: ThisWeekScreen.scheduleButton,
            onPressed: _openSchedule,
            icon: const Icon(
              Icons.event_outlined,
              semanticLabel: 'The weeks ahead',
            ),
            tooltip: 'The weeks ahead',
          ),
          IconButton(
            onPressed: _openJournal,
            icon: const Icon(
              Icons.menu_book_outlined,
              semanticLabel: 'Journal',
            ),
            tooltip: 'Journal',
          ),
          IconButton(
            onPressed: _openReminders,
            icon: const Icon(
              Icons.notifications_none,
              semanticLabel: 'Reminders',
            ),
            tooltip: 'Reminders',
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<Family?>(
          stream: _families,
          builder: (BuildContext context, AsyncSnapshot<Family?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            final Family? family = snapshot.data;
            if (family == null) {
              return _NoFamilyYet(onSetUp: _openSetup);
            }
            return StreamBuilder<String?>(
              stream: _youAre,
              builder: (BuildContext context, AsyncSnapshot<String?> who) =>
                  _Rota(
                    family: family,
                    today: _today,
                    youAre: who.data,
                    verses: _verses,
                    appVersion: widget.appVersion,
                  ),
            );
          },
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator(strokeWidth: 3),
    ),
  );
}

class _NoFamilyYet extends StatelessWidget {
  const _NoFamilyYet({required this.onSetUp});

  final Future<void> Function() onSetUp;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CentredMessage(
      padding: const EdgeInsets.all(32),
      children: <Widget>[
        // A ring with nothing filled: the shape of the thing, waiting.
        ExcludeSemantics(
          child: RotaMark(
            size: 84,
            current: -1,
            ringColour: theme.colorScheme.onSurfaceVariant.withValues(
              alpha: 0.22,
            ),
            currentColour: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'No rota yet',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Add everyone who takes a week, and the day your week turns '
          'over. The app will keep track from there.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton(onPressed: onSetUp, child: const Text('Set up the rota')),
      ],
    );
  }
}

class _Rota extends StatelessWidget {
  const _Rota({
    required this.family,
    required this.today,
    required this.verses,
    required this.appVersion,
    this.youAre,
  });

  final Family family;
  final CalendarDate today;
  final String? youAre;
  final Future<VerseForTheDay> verses;
  final AppVersion appVersion;

  @override
  Widget build(BuildContext context) {
    final RotaEngine engine = RotaEngine.forFamily(family);
    final Turn? current = engine.turnOn(today);

    if (current == null) {
      return _NotStartedYet(startsOn: engine.startedOn);
    }

    final List<Turn> ahead = engine.turnsFrom(
      current.weekEnd.addDays(1),
      count: 1,
    );

    // The card sits in the upper middle rather than at the top, and the
    // space below it is left on purpose: this screen answers one question,
    // and crowding it with a second thing would make the first harder to
    // find. The verse and the journal arrive on days 10 and 11 and have a
    // place waiting.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 24),
                    LeadingCard(turn: current, isYou: _isYou(current)),
                    if (ahead.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 28),
                      NextTurnTile(
                        turn: ahead.single,
                        isYou: _isYou(ahead.single),
                      ),
                    ],
                    const SizedBox(height: 44),
                    _TodaysVerse(verses: verses, today: today),
                    const SizedBox(height: 36),
                    _Version(appVersion: appVersion),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  bool _isYou(Turn turn) => youAre != null && turn.leader.id == youAre;
}

/// Today's verse, or nothing at all.
///
/// A verse that failed to load is not worth an error: the rota is the app,
/// and a missing verse should cost the screen nothing. So this renders empty
/// rather than apologising — the one place in this app where silence is the
/// right answer.
class _TodaysVerse extends StatelessWidget {
  const _TodaysVerse({required this.verses, required this.today});

  final Future<VerseForTheDay> verses;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VerseForTheDay>(
      future: verses,
      builder: (BuildContext context, AsyncSnapshot<VerseForTheDay> snapshot) {
        final VerseForTheDay? loaded = snapshot.data;
        if (loaded == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: VerseCard(
            verse: loaded.on(today),
            translation: loaded.translation.abbreviation,
          ),
        );
      },
    );
  }
}

/// Which build this is, at the foot of the home screen.
///
/// This screen is meant to answer one question, and a version string is not
/// it — so it sits below the verse, at the bottom of the scroll, in the
/// quietest type the theme has. It is there because the owner ships often
/// and needs to tell which build is on a phone without plugging it in, and
/// "which version am I running" is unanswerable from the outside otherwise.
class _Version extends StatelessWidget {
  const _Version({required this.appVersion});

  final AppVersion appVersion;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return FutureBuilder<String>(
      future: appVersion.describe(),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String? version = snapshot.data;
        if (version == null) {
          // Nothing, rather than a placeholder that shifts the layout when
          // the real answer arrives.
          return const SizedBox.shrink();
        }
        return Text(
          'Version $version',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}

class _NotStartedYet extends StatelessWidget {
  const _NotStartedYet({required this.startsOn});

  final CalendarDate startsOn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CentredMessage(
      padding: const EdgeInsets.all(32),
      children: <Widget>[
        Text(
          'The rota starts on',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          DateLabels.full(context, startsOn),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
