import 'package:flutter/material.dart';

import '../../domain/entities/verse.dart';

/// The verse for today.
///
/// Set quieter than the rota deliberately. The app answers one question and
/// this is not it — a verse that competed with the name would make the screen
/// about two things, and the whole point of Day 8's layout was that it is
/// about one.
///
/// The translation is named beside the reference because R3.2 requires it
/// wherever a verse appears, and because a quotation without its translation
/// cannot be looked up.
class VerseCard extends StatelessWidget {
  const VerseCard({required this.verse, required this.translation, super.key});

  final Verse verse;
  final String translation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      container: true,
      label: '${verse.text} — ${verse.reference}, $translation',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 28,
              height: 2,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 20),
            Text(
              verse.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.55,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${verse.reference} · $translation',
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
