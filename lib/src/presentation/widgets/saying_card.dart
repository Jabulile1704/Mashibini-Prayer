import 'package:flutter/material.dart';

import '../../domain/entities/saying.dart';
import '../brand/tokens.dart';

/// The saying for today.
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
            Container(
              width: 28,
              height: 2,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: Space.lg),

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
