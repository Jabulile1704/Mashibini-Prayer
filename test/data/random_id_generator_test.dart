import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/random_id_generator.dart';

void main() {
  group('RandomIdGenerator', () {
    test('keeps the prefix it is given', () {
      final RandomIdGenerator ids = RandomIdGenerator(random: Random(1));

      expect(ids.newId('m'), startsWith('m'));
      expect(ids.newId('c'), startsWith('c'));
      expect(ids.newId('skip'), startsWith('skip'));
    });

    test('uses only unambiguous characters', () {
      final RandomIdGenerator ids = RandomIdGenerator(random: Random(7));
      final RegExp allowed = RegExp(r'^m[23456789bcdfghjkmnpqrstvwxyz]{11}$');

      for (int i = 0; i < 200; i++) {
        final String id = ids.newId('m');
        expect(
          allowed.hasMatch(id),
          isTrue,
          reason:
              '$id contains a character that could be misread — no vowels, '
              'no 0/O or 1/l',
        );
      }
    });

    test('spells nothing, because it has no vowels', () {
      final RandomIdGenerator ids = RandomIdGenerator(random: Random(3));

      for (int i = 0; i < 100; i++) {
        expect(ids.newId('m').substring(1), isNot(matches(RegExp('[aeiou]'))));
      }
    });

    test('does not repeat itself over many draws', () {
      final RandomIdGenerator ids = RandomIdGenerator(random: Random(42));
      final Set<String> seen = <String>{};

      for (int i = 0; i < 5000; i++) {
        expect(
          seen.add(ids.newId('m')),
          isTrue,
          reason: 'a repeat within 5000 draws would make collisions likely',
        );
      }
    });

    test('two generators do not agree, which is the whole point', () {
      // Two phones, each with their own source of randomness. If these
      // collided, a merge would lose somebody — see ADR-008.
      final RandomIdGenerator phoneA = RandomIdGenerator(random: Random(1));
      final RandomIdGenerator phoneB = RandomIdGenerator(random: Random(2));

      final Set<String> fromA = <String>{
        for (int i = 0; i < 500; i++) phoneA.newId('m'),
      };
      final Set<String> fromB = <String>{
        for (int i = 0; i < 500; i++) phoneB.newId('m'),
      };

      expect(fromA.intersection(fromB), isEmpty);
    });

    test('defaults to a secure source when none is given', () {
      final RandomIdGenerator ids = RandomIdGenerator();

      final Set<String> seen = <String>{
        for (int i = 0; i < 100; i++) ids.newId('c'),
      };
      expect(seen, hasLength(100));
    });
  });
}
