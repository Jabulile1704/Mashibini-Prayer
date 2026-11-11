import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/turn.dart';
import '../../domain/ids.dart';
import '../../domain/rota/rota_engine.dart';
import '../../data/sources/assets/bundled_sayings.dart';
import '../../domain/saying/saying_for_the_day.dart';
import '../brand/mark.dart';
import '../brand/tokens.dart';
import '../widgets/centred_message.dart';
import '../widgets/date_text.dart';
import '../widgets/leading_card.dart';
import '../widgets/next_turn_tile.dart';
import '../widgets/saying_card.dart';
import 'setup_screen.dart';

/// The home screen: whose week it is, who is next, and when it changes hands.
class ThisWeekScreen extends StatefulWidget {
  const ThisWeekScreen({
    required this.repository,
    required this.settings,
    required this.ids,
    this.today,
    super.key,
  });

  final FamilyRepository repository;

  /// Which member is holding this phone — recorded during setup, absent
  /// until somebody says.
  final DeviceSettingsRepository settings;

  /// Passed through to setup, which mints ids for new members and cycles.
  final IdGenerator ids;

  /// The clock, injectable so a test can stand on any date.
  final CalendarDate Function()? today;

  @override
  State<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends State<ThisWeekScreen> {
  late final Stream<Family?> _families = widget.repository.watch();
  late final Stream<String?> _youAre = widget.settings.watchYouAre();
  late final Future<SayingForTheDay> _sayings = BundledSayings.load();

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());
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
      appBar: AppBar(title: const Text('Mashibini Prayer')),
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
                    sayings: _sayings,
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
      padding: const EdgeInsets.all(Space.xxl),
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
        const SizedBox(height: Space.xxl),
        Text(
          'No rota yet',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.md),
        Text(
          'Add everyone who takes a week, and the day your week turns '
          'over. The app will keep track from there.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.xxl),
        FilledButton(onPressed: onSetUp, child: const Text('Set up the rota')),
      ],
    );
  }
}

class _Rota extends StatelessWidget {
  const _Rota({
    required this.family,
    required this.today,
    required this.sayings,
    this.youAre,
  });

  final Family family;
  final CalendarDate today;
  final String? youAre;
  final Future<SayingForTheDay> sayings;

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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: Space.gutter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: Space.xl),
                    LeadingCard(turn: current, isYou: _isYou(current)),
                    if (ahead.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Space.xl),
                      NextTurnTile(
                        turn: ahead.single,
                        isYou: _isYou(ahead.single),
                      ),
                    ],
                    const SizedBox(height: Space.xxxl),
                    _TodaysSaying(sayings: sayings, today: today),
                    const SizedBox(height: Space.xxl),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  bool _isYou(Turn turn) => youAre != null && turn.leader.id == youAre;
}

/// Today's saying, or nothing at all.
class _TodaysSaying extends StatelessWidget {
  const _TodaysSaying({required this.sayings, required this.today});

  final Future<SayingForTheDay> sayings;
  final CalendarDate today;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SayingForTheDay>(
      future: sayings,
      builder: (BuildContext context, AsyncSnapshot<SayingForTheDay> snapshot) {
        final SayingForTheDay? loaded = snapshot.data;
        if (loaded == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.zero,
          child: SayingCard(saying: loaded.on(today)),
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
      padding: const EdgeInsets.all(Space.xxl),
      children: <Widget>[
        Text(
          'The rota starts on',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.sm),
        Text(
          DateLabels.full(context, startsOn),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
