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
import '../brand/tokens.dart';
import '../widgets/centred_message.dart';
import '../widgets/date_text.dart';

/// The weeks ahead, and the one control that changes them (R1.5, R1.4).
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

  /// The snack bar that says what just changed.
  static const Key changeSnack = Key('schedule.changed');

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final Stream<Family?> _families = widget.familyRepository.watch();
  late final Stream<String?> _youAre = widget.settings.watchYouAre();

  bool _busy = false;

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  /// Applies [change] and says what happened — out loud and on screen.
  Future<void> _edit(
    Family Function(Family) change,
    String announcement, {
    VoidCallback? onUndo,
  }) async {
    if (_busy) {
      return;
    }
    // Read before the first await: context must not be touched across one.
    final FlutterView view = View.of(context);
    final TextDirection direction = Directionality.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final Family? family = await widget.familyRepository.load();
      if (family != null) {
        await widget.familyRepository.save(change(family));

        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            key: ScheduleScreen.changeSnack,
            content: Text(announcement),
            duration: const Duration(seconds: 6),
            action: onUndo == null
                ? null
                : SnackBarAction(label: 'Undo', onPressed: onUndo),
          ),
        );
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

  /// Gives the week back.
  Future<void> _undo(CalendarDate weekStart, String name) => _edit(
    (Family f) => FamilyEditor.unskipTurn(f, weekStart: weekStart),
    '$name has their turn back',
  );

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
                      onUndo: () => _undo(weekStart, name),
                    ),
                    onUndo: (CalendarDate weekStart, String name) =>
                        _undo(weekStart, name),
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
      final CalendarDate startsOn = RotaEngine.forFamily(family).startedOn;
      return CentredMessage(
        padding: const EdgeInsets.all(Space.xxl),
        children: <Widget>[
          Text(
            'Nothing to plan yet',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.md),
          Text(
            'The rota starts on ${DateLabels.full(context, startsOn)}. '
            'The weeks ahead appear here from then.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
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

    final String rowLabel = <String>[
      isThisWeek ? 'This week' : when,
      who,
      if (passedOver != null)
        "${passedOver.displayName}'s turn was passed over",
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
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
                    const SizedBox(height: Space.xs),
                    Text(who, style: theme.textTheme.titleMedium),
                    if (passedOver != null) ...<Widget>[
                      const SizedBox(height: Space.xs),
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
          const SizedBox(width: Space.md),
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
