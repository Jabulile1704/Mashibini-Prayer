import 'package:flutter/material.dart';

import '../../data/sources/assets/bundled_sayings.dart';
import '../../data/sources/platform/app_version.dart';
import '../../domain/entities/saying.dart';
import '../../domain/saying/saying_for_the_day.dart';
import '../brand/mark.dart';
import '../brand/tokens.dart';

/// What the app does, what it does not, and which build this is.
class AboutScreen extends StatelessWidget {
  const AboutScreen({
    required this.appVersion,
    required this.canSync,
    this.sayings,
    super.key,
  });

  final AppVersion appVersion;

  /// Whether this build can share the rota between phones (#75).
  ///
  /// Passed in rather than written into the copy, because the copy was
  /// wrong for the whole of v2.2.0's development and a test held it there
  /// (#157). `_SayingsSection` below does the same thing with
  /// `SayingSource.reviewed`, for the same reason: a claim the app makes
  /// about itself should be derived from the thing it is claiming about.
  final bool canSync;

  /// Only so a test can hand in its own. Null means the ones that ship,
  /// which is every case that is not a test.
  final Future<SayingForTheDay>? sayings;

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
                  'Nobody else in the family can read it, and neither can '
                  'we. That is true even now that the rota is shared — the '
                  'rota goes up, the journal never does.',
            ),
            if (canSync)
              _Section(
                heading: 'The phones share one rota',
                body:
                    'Everybody who signs in sees the same rota. Skip a week '
                    'on one phone and the others know. Change it with no '
                    'signal and it goes up when the signal comes back.\n\n'
                    'Somebody already in the family has to let a new phone '
                    'in — see The family\'s phones in Settings. There is no '
                    'code that lets a stranger in.',
              ),
            _Section(
              heading: 'It works with no signal',
              body:
                  'Everything it needs is already on the phone, including the '
                  'sayings. Whose week it is is worked out from the calendar '
                  'rather than fetched, so an aeroplane and a full signal '
                  'give the same answer.',
            ),

            _SayingsSection(sayings: sayings),

            const SizedBox(height: Space.sm),
            Text('WHAT IT CANNOT DO YET', style: theme.textTheme.labelLarge),
            const SizedBox(height: Space.md),
            if (!canSync)
              _Section(
                heading: 'The phones do not see each other',
                body:
                    'Each phone keeps its own copy of the rota. Skipping a '
                    'week on one phone does not show up on another one.',
              ),
            _Section(
              heading: 'It cannot remind the whole family',
              body:
                  'Each phone can remind its own owner before their week, '
                  'which it does if you ask it to. Reaching everybody else '
                  'needs a server, and this app does not have one.',
            ),
            _Section(
              heading: 'Reinstalling loses your journal',
              body: canSync
                  ? 'On an iPhone this app has to be installed again every '
                        'week or so, and installing it removes the old copy '
                        'along with everything on it.\n\n'
                        'The rota comes back: sign in and it is there. Your '
                        'journal does not, because it was never anywhere '
                        'else. So the part anybody could type again in a '
                        'minute is the part that survives, and the part '
                        'nobody can is the part that does not.\n\n'
                        'Keep a copy from Settings before you reinstall. '
                        'That is the only thing that saves it.'
                  : 'On an iPhone this app has to be installed again every '
                        'week or so, and installing it removes the old copy '
                        'along with everything on it. The rota takes a '
                        'minute to enter again. What you wrote does not come '
                        'back.\n\n'
                        'Keep a copy from Settings before you reinstall. '
                        'That is the only thing that saves it.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the sayings come from, read from the file that holds them.
class _SayingsSection extends StatefulWidget {
  const _SayingsSection({required this.sayings});

  final Future<SayingForTheDay>? sayings;

  @override
  State<_SayingsSection> createState() => _SayingsSectionState();
}

class _SayingsSectionState extends State<_SayingsSection> {
  late final Future<SayingForTheDay> _sayings =
      widget.sayings ?? BundledSayings.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SayingForTheDay>(
      future: _sayings,
      builder: (BuildContext context, AsyncSnapshot<SayingForTheDay> built) {
        final SayingForTheDay? loaded = built.data;
        if (loaded == null) {
          return const SizedBox.shrink();
        }

        final SayingSource source = loaded.source;
        final String languages = _list(source.languages);

        return _Section(
          heading: 'Where the sayings come from',
          body:
              '${loaded.count} ${source.tradition} sayings, in $languages. '
              '${source.notice}'
              '${source.reviewed ? '' : '\n\n'
                        'Nobody who speaks these languages has checked the '
                        'spelling yet. If something reads wrong to you, it '
                        'probably is wrong — say so and it will be fixed.'}',
        );
      },
    );
  }

  /// "isiXhosa, isiZulu and Sesotho" — an Oxford-comma-free list, because it
  /// is read aloud in a sentence rather than scanned in a table.
  static String _list(List<String> items) {
    if (items.length < 2) {
      return items.join();
    }
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
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
