import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/skipped_turn.dart';
import '../../domain/entities/turn.dart';
import '../../domain/ids.dart';
import '../../domain/rota/family_editor.dart';
import '../../domain/rota/rota_engine.dart';
import '../widgets/centred_message.dart';
import '../widgets/date_text.dart';

/// The weeks ahead, and the one control that changes them (R1.5, R1.4).
///
/// Two requirements share a screen because they are the same question asked
/// twice. Seeing the cycle ahead is only useful if you can act on what you
/// see — "Mama is away that week" is a thought you have *while* reading the
/// list, and making somebody remember it until they find a settings page
/// elsewhere is how it gets forgotten.
///
/// A skipped week keeps its row rather than vanishing. The rota moves on, so
/// the row shows whoever leads now — but it also says whose turn was passed
/// over, because otherwise a skip becomes invisible the moment it is made and
/// there is nothing left to undo.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    required this.familyRepository,
    required this.settings,
    required this.ids,
    this.today,
    super.key,
  });

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settings;
  final IdGenerator ids;
  final CalendarDate Function()? today;

  /// How many weeks the list shows. R1.5 asks for eight.
  static const int weeksAhead = 8;

  static Key skipButton(CalendarDate weekStart) =>
      Key('schedule.skip.$weekStart');
  static Key undoButton(CalendarDate weekStart) =>
      Key('schedule.undo.$weekStart');

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final Stream<Family?> _families = widget.familyRepository.watch();
  late final Stream<String?> _youAre = widget.settings.watchYouAre();

  bool _busy = false;

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  Future<void> _edit(
    Family Function(Family) change,
    String announcement,
  ) async {
    if (_busy) {
      return;
    }
    // Read before the first await: context must not be touched across one.
    final FlutterView view = View.of(context);
    final TextDirection direction = Directionality.of(context);

    setState(() => _busy = true);
    try {
      final Family? family = await widget.familyRepository.load();
      if (family != null) {
        await widget.familyRepository.save(change(family));
        // Spoken aloud, because a screen reader would otherwise be told only
        // that one button vanished and another appeared somewhere in a list —
        // which is not the same as being told whose week changed hands.
        //
        // **Deliberately not awaited.** The accessibility channel has no
        // listener when no screen reader is running, so the send never
        // completes — and awaiting it left every button on this screen
        // disabled forever, because the `finally` below never ran. Found on
        // the simulator; the widget tests pass either way, since the test
        // binding answers the channel immediately.
        unawaited(
          SemanticsService.sendAnnouncement(view, announcement, direction),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The weeks ahead')),
      body: SafeArea(
        child: StreamBuilder<Family?>(
          stream: _families,
          builder: (BuildContext context, AsyncSnapshot<Family?> snapshot) {
            final Family? family = snapshot.data;
            if (family == null) {
              return const SizedBox.shrink();
            }
            return StreamBuilder<String?>(
              stream: _youAre,
              builder: (BuildContext context, AsyncSnapshot<String?> who) =>
                  _Weeks(
                    family: family,
                    today: _today,
                    youAre: who.data,
                    busy: _busy,
                    onSkip: (CalendarDate weekStart, String name) => _edit(
                      (Family f) => FamilyEditor.skipTurn(
                        f,
                        weekStart: weekStart,
                        today: _today,
                        ids: widget.ids,
                      ),
                      "$name's turn was passed over",
                    ),
                    onUndo: (CalendarDate weekStart, String name) => _edit(
                      (Family f) =>
                          FamilyEditor.unskipTurn(f, weekStart: weekStart),
                      '$name has their turn back',
                    ),
                  ),
            );
          },
        ),
      ),
    );
  }
}

typedef _WeekAction = Future<void> Function(CalendarDate weekStart, String who);

class _Weeks extends StatelessWidget {
  const _Weeks({
    required this.family,
    required this.today,
    required this.busy,
    required this.onSkip,
    required this.onUndo,
    this.youAre,
  });

  final Family family;
  final CalendarDate today;
  final String? youAre;
  final bool busy;
  final _WeekAction onSkip;
  final _WeekAction onUndo;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Turn> turns = RotaEngine.forFamily(family)
        .turnsFrom(today, count: ScheduleScreen.weeksAhead);

    if (turns.isEmpty) {
      return CentredMessage(
        padding: const EdgeInsets.all(32),
        children: <Widget>[
          Text(
            'The rota has not started yet, so there are no weeks to show.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: turns.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1, indent: 20, endIndent: 20),
      itemBuilder: (BuildContext context, int index) {
        final Turn turn = turns[index];
        final SkippedTurn? skipped = FamilyEditor.skipOn(
          family,
          turn.weekStart,
        );
        return _WeekRow(
          turn: turn,
          isThisWeek: index == 0 && turn.contains(today),
          isYou: youAre != null && turn.leader.id == youAre,
          passedOver: skipped == null
              ? null
              : family.membersById[skipped.memberId],
          busy: busy,
          onSkip: onSkip,
          onUndo: onUndo,
        );
      },
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.turn,
    required this.isThisWeek,
    required this.isYou,
    required this.passedOver,
    required this.busy,
    required this.onSkip,
    required this.onUndo,
  });

  final Turn turn;
  final bool isThisWeek;
  final bool isYou;

  /// Whose turn this week was, before it was skipped.
  final Member? passedOver;

  final bool busy;
  final _WeekAction onSkip;
  final _WeekAction onUndo;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String who = isYou ? 'You' : turn.leader.displayName;
    final String when = DateLabels.full(context, turn.weekStart);
    final Member? passedOver = this.passedOver;

    // Read as one thing: three separate lines would be three stops, and
    // "Sisi" on its own tells somebody nothing about which week it is.
    final String rowLabel = <String>[
      isThisWeek ? 'This week' : when,
      who,
      if (passedOver != null)
        "${passedOver.displayName}'s turn was passed over",
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Semantics(
              container: true,
              label: rowLabel,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isThisWeek ? 'This week' : when,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(who, style: theme.textTheme.titleMedium),
                    if (passedOver != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        "${passedOver.displayName}'s turn was passed over",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // The buttons carry the week in their label. A list of seven
          // buttons all announcing "Skip" is a list nobody can use by ear.
          if (passedOver != null)
            TextButton(
              key: ScheduleScreen.undoButton(turn.weekStart),
              onPressed: busy
                  ? null
                  : () => onUndo(turn.weekStart, passedOver.displayName),
              child: Text(
                'Undo',
                semanticsLabel:
                    'Undo, give ${passedOver.displayName} back the week '
                    'of $when',
              ),
            )
          else if (!isThisWeek)
            TextButton(
              key: ScheduleScreen.skipButton(turn.weekStart),
              onPressed: busy
                  ? null
                  : () => onSkip(turn.weekStart, turn.leader.displayName),
              child: Text(
                'Skip',
                semanticsLabel:
                    'Skip ${turn.leader.displayName}, week of $when',
              ),
            ),
        ],
      ),
    );
  }
}
