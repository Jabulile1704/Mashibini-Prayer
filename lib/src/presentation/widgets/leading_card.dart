import 'package:flutter/material.dart';

import '../../domain/entities/turn.dart';
import 'date_text.dart';

/// Whose week it is — the one thing this app exists to say.
///
/// Deliberately the largest thing on the screen. Everything else is context
/// for it.
class LeadingCard extends StatelessWidget {
  const LeadingCard({required this.turn, required this.isYou, super.key});

  final Turn turn;

  /// Whether the leader is the person holding the phone.
  ///
  /// When it is, the card speaks in the second person: being told your own
  /// name is a strange way to be reminded of your own turn.
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String headline = isYou ? "It's your week" : turn.leader.displayName;

    return Semantics(
      container: true,
      header: true,
      label: isYou
          ? "It's your week to lead family prayer"
          : '${turn.leader.displayName} is leading family prayer this week',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'This week',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                headline,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'until ${DateLabels.full(context, turn.weekEnd)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
