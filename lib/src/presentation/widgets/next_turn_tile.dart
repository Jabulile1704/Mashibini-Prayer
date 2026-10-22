import 'package:flutter/material.dart';

import '../../domain/entities/turn.dart';
import 'date_text.dart';

/// Who takes the next turn, and the day it starts.
///
/// The date matters as much as the name: "Tata, from Sunday" is a reminder;
/// "Tata next" is trivia.
class NextTurnTile extends StatelessWidget {
  const NextTurnTile({required this.turn, required this.isYou, super.key});

  final Turn turn;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final String who = isYou ? 'You' : turn.leader.displayName;
    final String when = DateLabels.full(context, turn.weekStart);

    return Semantics(
      container: true,
      label: '$who next, from $when',
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: const Icon(Icons.arrow_forward),
        title: Text(who, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('from $when'),
      ),
    );
  }
}
