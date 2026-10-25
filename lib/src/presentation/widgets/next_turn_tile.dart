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
    final ThemeData theme = Theme.of(context);
    final String who = isYou ? 'You' : turn.leader.displayName;
    final String when = DateLabels.full(context, turn.weekStart);

    return Semantics(
      container: true,
      label: '$who next, from $when',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.arrow_forward,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(who, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('from $when', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
