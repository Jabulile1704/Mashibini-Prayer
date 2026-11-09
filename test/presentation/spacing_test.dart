import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Day 22's restyle, kept.
///
/// `Space` was written on Day 17 and the screens went on using their own
/// numbers for five days, because nothing stopped them. There were **28** raw
/// `SizedBox` heights against 19 tokenised ones, and seven files on
/// hand-picked `EdgeInsets` — thirteen distinct gaps across the app, two of
/// which were meant to look the same and did not.
///
/// A design system nothing enforces is a suggestion. This reads the source
/// and fails on a gap that is a number, which is the only way the scale stays
/// the scale after the day that introduced it.
///
/// It deliberately does **not** police every number in the layer. A hexagon's
/// radius, an icon's size, the 28×2 rule under the saying — those are the
/// dimensions of things, and `Space` is about rhythm between them. The two
/// patterns below are the ones that are always rhythm: a `SizedBox` with one
/// axis set is a gap, and padding is padding.
void main() {
  /// Every Dart file in the presentation layer, except the one that defines
  /// the numbers.
  List<File> presentationSources() {
    final Directory root = Directory('lib/src/presentation');
    expect(
      root.existsSync(),
      isTrue,
      reason: 'run from the package root; ${root.absolute.path} does not exist',
    );
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .where((File f) => !f.path.endsWith('brand/tokens.dart'))
        .toList();
  }

  /// A `SizedBox` standing in for a gap: **one** axis, a bare number.
  ///
  /// Two axes is a shape — a photograph's placeholder, a swatch — and `Space`
  /// is about the rhythm between things rather than how big they are. The
  /// first version of this said exactly that in its doc comment, matched on
  /// the opening of the call and so caught both, and had a self-test
  /// asserting the wrong one of the two. It was found by the guard flagging
  /// a legitimate `SizedBox(width: 64, height: 64)` the next day.
  ///
  /// The closing bracket is the whole fix: one argument, then `)`.
  final RegExp gap = RegExp(
    r'SizedBox\(\s*(?:height|width):\s*\d+(?:\.\d+)?\s*,?\s*\)',
  );

  /// Padding given a number instead of a token.
  ///
  /// `Space.fabClearance + Space.md` passes, which is the point of naming
  /// that one: the rule is against anonymous numbers, not arithmetic.
  ///
  /// **Zero is allowed.** `fromLTRB(Space.lg, 0, Space.lg, Space.sm)` means
  /// *no padding on that side*, which is not an unnamed design decision —
  /// there is no token for nothing, and inventing `Space.none` would be a
  /// word for a thing that already has one. The first version of this check
  /// flagged four such lines, which is how the exception got written down
  /// rather than assumed.
  final RegExp edgeInsets = RegExp(r'EdgeInsets\.\w+\(([^)]*)\)');
  final RegExp number = RegExp(r'(?<![\w.])(\d+(?:\.\d+)?)');
  final RegExp anyName = RegExp(r'[A-Za-z_]');

  /// Whether any argument is a number and nothing else.
  ///
  /// Per argument rather than per call, and the label is dropped first, so
  /// `bottom: 12` is judged on `12`. An argument that names anything —
  /// `Space.lg`, `Space.fabClearance + Space.md`, `inset ? _Cell.diameter /
  /// 2 : 0` — is somebody's decision with a name on it, which is all this
  /// guard has ever been asking for. The second of those was allowed from
  /// the start; the third was not, and was a false positive on the day the
  /// family tree landed.
  bool isPaddingByNumber(String line) {
    for (final RegExpMatch call in edgeInsets.allMatches(line)) {
      for (final String argument in call.group(1)!.split(',')) {
        final int label = argument.indexOf(':');
        final String value = label == -1
            ? argument
            : argument.substring(label + 1);
        if (anyName.hasMatch(value)) {
          continue;
        }
        for (final RegExpMatch found in number.allMatches(value)) {
          if (double.parse(found.group(1)!) != 0) {
            return true;
          }
        }
      }
    }
    return false;
  }

  test('no gap in the presentation layer is a bare number', () {
    final List<String> offences = <String>[];

    for (final File source in presentationSources()) {
      final List<String> lines = source.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (gap.hasMatch(lines[i])) {
          offences.add('${source.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason:
          'use a Space.* token. If none of the seven steps fits, that is the '
          'scale telling you the layout has not been decided yet — which is '
          'what it is for.\n${offences.join('\n')}',
    );
  });

  test('no padding in the presentation layer is a bare number', () {
    final List<String> offences = <String>[];

    for (final File source in presentationSources()) {
      final List<String> lines = source.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (isPaddingByNumber(lines[i])) {
          offences.add('${source.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason:
          'use Space.gutter, Space.screen, or a Space.* step. A measurement '
          'that genuinely is not a step on the scale gets a name on `Space` '
          'and a comment saying why — see Space.fabClearance.\n'
          '${offences.join('\n')}',
    );
  });

  test('and this test can actually fail', () {
    // The rule from Day 21, applied on the way in rather than afterwards:
    // two of the three assertions written for #111 could not fail, and the
    // only thing that caught them was breaking them on purpose. A guard
    // whose regex has quietly stopped matching is a guard that reports a
    // clean codebase forever.
    expect(gap.hasMatch('const SizedBox(height: 24),'), isTrue);
    expect(gap.hasMatch('const SizedBox(height: Space.xl),'), isFalse);
    expect(
      gap.hasMatch('SizedBox(width: 34, height: 34)'),
      isFalse,
      reason: 'two axes is a shape, not a gap — which this once got wrong',
    );

    expect(isPaddingByNumber('padding: const EdgeInsets.all(32),'), isTrue);
    expect(
      isPaddingByNumber('padding: const EdgeInsets.all(Space.xxl),'),
      isFalse,
    );
    expect(
      isPaddingByNumber(
        'padding: const EdgeInsets.only(bottom: Space.fabClearance + '
        'Space.md),',
      ),
      isFalse,
      reason: 'arithmetic on named steps is not a bare number',
    );
    expect(
      isPaddingByNumber(
        'padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),',
      ),
      isFalse,
      reason: 'zero means no padding, and needs no name',
    );
    expect(
      isPaddingByNumber(
        'padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 10),',
      ),
      isTrue,
      reason: 'a real number beside a zero is still a real number',
    );
    expect(
      isPaddingByNumber(
        'padding: EdgeInsets.only(left: inset ? _Cell.diameter / 2 : 0),',
      ),
      isFalse,
      reason: 'arithmetic on a named dimension is not a bare number',
    );
  });
}
