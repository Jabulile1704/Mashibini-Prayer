import 'package:flutter/material.dart';

import '../../domain/entities/turn.dart';
import '../brand/mark.dart';
import '../brand/tokens.dart';
import 'date_text.dart';

/// Whose week it is — the one thing this app exists to say.
class LeadingCard extends StatelessWidget {
  const LeadingCard({required this.turn, required this.isYou, super.key});

  final Turn turn;

  /// Whether the leader is the person holding the phone.
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
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            Space.xxl,
            Space.xl,
            Space.xxl,
          ),
          child: Column(
            children: <Widget>[
              ExcludeSemantics(
                child: RotaMark(
                  size: 92,
                  parts: turn.cycleLength,
                  current: turn.position,
                  ringColour: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.28,
                  ),
                  currentColour: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: Space.xl),
              Text('This week', style: theme.textTheme.labelLarge),
              const SizedBox(height: Space.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  headline,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                'until ${DateLabels.full(context, turn.weekEnd)}',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
