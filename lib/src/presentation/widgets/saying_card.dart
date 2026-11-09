import 'package:flutter/material.dart';

import '../../domain/entities/saying.dart';
import '../brand/tokens.dart';

/// The saying for today.
///
/// Set quieter than the rota deliberately. The app answers one question and
/// this is not it — a saying that competed with the name would make the
/// screen about two things, and the whole point of Day 8's layout was that
/// it is about one.
///
/// The language is named beneath because R3.2 requires the attribution
/// wherever a saying appears, and because a proverb without its language is
/// a sentence nobody can place. It replaced naming a translation: a
/// traditional saying has no translator, and pretending otherwise would be
/// the sort of tidy falsehood this app has no use for (ADR-025).
class SayingCard extends StatelessWidget {
  const SayingCard({required this.saying, super.key});

  final Saying saying;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? original = saying.original;

    return Semantics(
      container: true,
      label: original == null
          ? '${saying.text} — a ${saying.language} saying'
          : '$original. ${saying.text} — a ${saying.language} saying',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // A rule, not a gap: 28 wide and 2 high is a drawn line whose
            // dimensions are what it looks like.
            Container(
              width: 28,
              height: 2,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: Space.lg),

            // The saying's own language leads, where there is one. It is
            // the family's tongue and the English is the gloss, not the
            // other way round.
            if (original != null) ...<Widget>[
              Text(
                original,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: Space.sm),
            ],

            Text(
              saying.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.55,
                color: theme.colorScheme.onSurface.withValues(
                  alpha: original == null ? 0.82 : 0.70,
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Text(
              saying.language,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
