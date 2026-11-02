import 'package:flutter/material.dart';

import 'mark.dart';
import 'tokens.dart';
import 'type_scale.dart';

/// Every token and component on one screen, so the design system can be
/// looked at rather than reasoned about.
///
/// Reached by building with `--dart-define=GALLERY=true`, which costs
/// nothing in a normal build and means reviewing the system never requires
/// editing `main.dart` and remembering to put it back.
///
/// It exists for Day 21, when every screen is restyled: the question "is
/// this spacing right?" is answerable here, once, instead of five times in
/// five screens.
class BrandGallery extends StatelessWidget {
  const BrandGallery({super.key});

  static const bool requested = bool.fromEnvironment('GALLERY');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colours = theme.colorScheme;
    final Brightness brightness = theme.brightness;

    return Scaffold(
      appBar: AppBar(
        title: Text(brightness == Brightness.light ? 'Light' : 'Dark'),
      ),
      body: ListView(
        padding: Space.screen,
        children: <Widget>[
          const _Section('Type'),
          Text('Jabulile', style: theme.textTheme.displaySmall),
          const SizedBox(height: Space.sm),
          Text('No rota yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: Space.sm),
          Text('Mama', style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.sm),
          Text(
            'Love is patient and is kind.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Space.sm),
          Text(
            'The evening before your turn starts.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Space.sm),
          Text('Sunday, 1 November 2026', style: theme.textTheme.bodySmall),
          const SizedBox(height: Space.sm),
          Text('THIS WEEK', style: theme.textTheme.labelLarge),

          const _Section('Spacing'),
          const _Ruler('xs', Space.xs),
          const _Ruler('sm', Space.sm),
          const _Ruler('md', Space.md),
          const _Ruler('lg', Space.lg),
          const _Ruler('xl', Space.xl),
          const _Ruler('xxl', Space.xxl),
          const _Ruler('xxxl', Space.xxxl),

          const _Section('Colour'),
          _Swatch('surface', colours.surface, colours.onSurface),
          _Swatch(
            'surfaceContainerHighest',
            colours.surfaceContainerHighest,
            colours.onSurface,
          ),
          _Swatch('primary', colours.primary, colours.onPrimary),
          // Shown with its container rather than with `onSecondary`: the
          // accent is a graphics colour, and a swatch that renders a word on
          // it would be advertising a pair that fails AA for text.
          _Swatch(
            'secondary (graphics only)',
            colours.secondary,
            colours.onSecondary,
          ),
          _Swatch(
            'secondaryContainer + onSecondaryContainer',
            colours.secondaryContainer,
            colours.onSecondaryContainer,
          ),

          const _Section('The mark'),
          Row(
            children: <Widget>[
              for (int people = 2; people <= 5; people++) ...<Widget>[
                RotaMark(
                  size: 44,
                  parts: people,
                  current: 1,
                  ringColour: colours.onSurfaceVariant.withValues(alpha: 0.28),
                  currentColour: colours.secondary,
                ),
                const SizedBox(width: Space.lg),
              ],
            ],
          ),

          const _Section('Controls'),
          FilledButton(onPressed: () {}, child: const Text('Set up the rota')),
          const SizedBox(height: Space.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () {}, child: const Text('Skip')),
          ),
          const SizedBox(height: Space.md),
          SwitchListTile(
            value: true,
            onChanged: (bool _) {},
            title: const Text('Remind me before my week'),
            subtitle: const Text('The evening before your turn starts.'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: Space.md),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Person 1',
              hintText: 'Their name',
            ),
          ),

          const _Section('Surfaces'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                children: <Widget>[
                  Text('THIS WEEK', style: theme.textTheme.labelLarge),
                  const SizedBox(height: Space.sm),
                  Text('Jabulile', style: theme.textTheme.displaySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          const Divider(),
          const SizedBox(height: Space.xxl),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xxl, bottom: Space.lg),
    child: Text(
      title.toUpperCase(),
      style: TypeScale.label.copyWith(
        color: Theme.of(context).colorScheme.secondary,
      ),
    ),
  );
}

class _Ruler extends StatelessWidget {
  const _Ruler(this.name, this.size);

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(name, style: theme.textTheme.bodySmall),
          ),
          Container(
            width: size,
            height: Space.lg,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: Space.sm),
          Text('${size.toInt()}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.background, this.foreground);

  final String name;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: Space.sm),
    padding: const EdgeInsets.all(Space.lg),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(Radii.sm),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Text(name, style: TypeScale.body.copyWith(color: foreground)),
  );
}
