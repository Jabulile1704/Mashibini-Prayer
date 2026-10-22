import 'package:flutter/material.dart';

import '../../data/repositories/family_repository.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/turn.dart';
import '../../domain/rota/rota_engine.dart';
import '../widgets/date_text.dart';
import '../widgets/leading_card.dart';
import '../widgets/next_turn_tile.dart';

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
    this.youAre,
    this.today,
    super.key,
  });

  final FamilyRepository repository;

  /// Which member is holding this phone, if that is known.
  ///
  /// Null until setup records it (Day 6). When null the screen simply uses
  /// names — it never guesses that the leader is you, because being told
  /// someone else's turn is yours is worse than being told a name.
  final String? youAre;

  /// The clock, injectable so a test can stand on any date.
  ///
  /// The domain refuses to read a clock (ADR-002); this is the boundary where
  /// one is finally read, and it is a parameter rather than a call so the
  /// screen is testable on any week of the next decade.
  final CalendarDate Function()? today;

  @override
  State<ThisWeekScreen> createState() => _ThisWeekScreenState();
}

class _ThisWeekScreenState extends State<ThisWeekScreen> {
  late final Stream<Family?> _families = widget.repository.watch();

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

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
              return const _NoFamilyYet();
            }
            return _Rota(family: family, today: _today, youAre: widget.youAre);
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
  const _NoFamilyYet();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
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
            const SizedBox(height: 24),
            // Setup arrives on day 6; the button is here so the empty state
            // says what happens next rather than only what is missing.
            FilledButton(onPressed: null, child: const Text('Set up the rota')),
          ],
        ),
      ),
    );
  }
}

class _Rota extends StatelessWidget {
  const _Rota({required this.family, required this.today, this.youAre});

  final Family family;
  final CalendarDate today;
  final String? youAre;

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

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LeadingCard(turn: current, isYou: _isYou(current)),
        ),
        if (ahead.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Divider(indent: 24, endIndent: 24),
          NextTurnTile(turn: ahead.single, isYou: _isYou(ahead.single)),
        ],
      ],
    );
  }

  bool _isYou(Turn turn) => youAre != null && turn.leader.id == youAre;
}

class _NotStartedYet extends StatelessWidget {
  const _NotStartedYet({required this.startsOn});

  final CalendarDate startsOn;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
        ),
      ),
    );
  }
}
