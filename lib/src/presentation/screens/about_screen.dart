import 'package:flutter/material.dart';

import '../../data/sources/platform/app_version.dart';
import '../brand/mark.dart';
import '../brand/tokens.dart';

/// What the app does, what it does not, and which build this is.
///
/// The version used to sit at the foot of This Week, in the smallest type in
/// the app, where it was the only thing on the screen nobody needed. It is
/// here now, with the three things worth saying next to it.
///
/// The limits are stated rather than omitted. Every one of them is already
/// in the release notes and in the requirements; a family reading the app
/// should not have to go looking in a repository to find out that their
/// phones do not yet see each other.
class AboutScreen extends StatelessWidget {
  const AboutScreen({required this.appVersion, super.key});

  final AppVersion appVersion;

  static const Key version = Key('about.version');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          padding: Space.screen,
          children: <Widget>[
            Center(
              child: ExcludeSemantics(
                child: RotaMark(
                  size: 72,
                  ringColour: theme.colorScheme.onSurfaceVariant,
                  currentColour: theme.colorScheme.secondary,
                ),
              ),
            ),
            const SizedBox(height: Space.lg),
            Text(
              'Mashibini Prayer',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.xs),
            Center(
              child: FutureBuilder<String>(
                future: appVersion.describe(),
                builder: (BuildContext context, AsyncSnapshot<String> built) {
                  final String? value = built.data;
                  if (value == null) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    key: AboutScreen.version,
                    'Version $value',
                    style: theme.textTheme.bodySmall,
                  );
                },
              ),
            ),

            const SizedBox(height: Space.xxl),
            _Section(
              heading: 'What it is for',
              body:
                  'It keeps track of whose week it is to lead family prayer, '
                  'so that nobody has to remember and nobody has to ask. '
                  'Four people, one week each, and it carries on from where '
                  'the family already was.',
            ),
            _Section(
              heading: 'Your journal stays on your phone',
              body:
                  'What you write is stored on this phone and sent nowhere. '
                  'Nobody else in the family can read it, and neither can we.',
            ),
            _Section(
              heading: 'It works with no signal',
              body:
                  'Everything it needs is already on the phone, including the '
                  'verses. Whose week it is is worked out from the calendar '
                  'rather than fetched, so an aeroplane and a full signal '
                  'give the same answer.',
            ),

            const SizedBox(height: Space.sm),
            Text('WHAT IT CANNOT DO YET', style: theme.textTheme.labelLarge),
            const SizedBox(height: Space.md),
            _Section(
              heading: 'The phones do not see each other',
              body:
                  'Each phone keeps its own copy of the rota. Skipping a week '
                  'on one phone does not show up on another one yet.',
            ),
            _Section(
              heading: 'It cannot remind the whole family',
              body:
                  'Each phone can remind its own owner before their week, '
                  'which it does if you ask it to. Reaching everybody else '
                  'needs a server, and this app does not have one.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(heading, style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.xs),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
