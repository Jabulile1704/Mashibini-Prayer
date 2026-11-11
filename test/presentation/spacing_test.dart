import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Day 22's restyle, kept.
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
  final RegExp gap = RegExp(
    r'SizedBox\(\s*(?:height|width):\s*\d+(?:\.\d+)?\s*,?\s*\)',
  );

  /// Padding given a number instead of a token.
  final RegExp edgeInsets = RegExp(r'EdgeInsets\.\w+\(([^)]*)\)');
  final RegExp number = RegExp(r'(?<![\w.])(\d+(?:\.\d+)?)');
  final RegExp anyName = RegExp(r'[A-Za-z_]');

  /// Whether any argument is a number and nothing else.
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
