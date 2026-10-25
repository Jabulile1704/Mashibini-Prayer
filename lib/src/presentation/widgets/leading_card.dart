import 'package:flutter/material.dart';

import '../../domain/entities/turn.dart';
import '../brand/mark.dart';
import 'date_text.dart';

/// Whose week it is — the one thing this app exists to say.
///
/// The ring above the name is the app's own mark, drawn live: as many arcs as
/// there are people, with this week's filled. So the icon on the home screen
/// is a generic cycle, and the same shape inside the app is *your* cycle,
/// showing where the family has got to. It answers "who is next after next"
/// without anybody reading a list.
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
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
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
              const SizedBox(height: 28),
              Text('This week', style: theme.textTheme.labelLarge),
              const SizedBox(height: 10),
              Text(
                headline,
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
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
