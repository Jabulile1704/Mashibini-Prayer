import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/random_id_generator.dart';
import 'package:mashibini_prayer/src/domain/family/codes.dart';
import 'package:mashibini_prayer/src/domain/ids.dart';

/// The two codes #143 asks people to move between phones.
void main() {
  group('FamilyCode', () {
    test('accepts what the generator makes, every time', () {
      final RandomIdGenerator ids = RandomIdGenerator();
      for (int i = 0; i < 500; i++) {
        final String id = ids.newId('f');
        expect(FamilyCode.parse(id), id, reason: id);
      }
    });

    test('forgives how a person types it', () {
      const String id = 'fqx7n2bkrmdh';
      for (final String typed in <String>[
        'fqx7n2bkrmdh',
        'FQX7N2BKRMDH',
        ' fqx7n2bkrmdh ',
        'fqx7-n2bk-rmdh',
        'fqx7 n2bk rmdh',
        '#fqx7n2bkrmdh',
        'f_qx7n2bkrmdh',
      ]) {
        expect(FamilyCode.parse(typed), id, reason: typed);
      }
    });

    test('refuses the one the hardcode used to produce', () {
      // Every family created before #148 was called f1, so somebody who
      // remembers that is typing something that cannot be a code.
      expect(FamilyCode.parse('f1'), isNull);
    });

    test('refuses what no generator could have made', () {
      for (final String typed in <String>[
        '',
        'f',
        'fqx7n2bkrmd', // one short
        'fqx7n2bkrmdhj', // one long
        'mqx7n2bkrmdh', // a member, not a family
        'faaaaaaaaaaa', // `a` is not in the alphabet
        'foix7n2bkrmd', // nor are the look-alikes
        'fqx7n2bkrmd!',
      ]) {
        expect(FamilyCode.parse(typed), isNull, reason: typed);
      }
    });

    test('and the alphabet has nothing that looks like anything else', () {
      // The reason case can be folded without losing information.
      expect(IdScheme.alphabet, isNot(contains('0')));
      expect(IdScheme.alphabet, isNot(contains('1')));
      expect(IdScheme.alphabet, isNot(contains('l')));
      expect(IdScheme.alphabet, isNot(contains('o')));
      for (final String vowel in <String>['a', 'e', 'i', 'u']) {
        expect(IdScheme.alphabet, isNot(contains(vowel)));
      }
      expect(IdScheme.alphabet, IdScheme.alphabet.toLowerCase());
    });
  });

  group('AccountCode', () {
    test('accepts a Firebase uid', () {
      const String uid = 'kJ8sQ2mNpR4tVwXyZa1bCd3e';
      expect(AccountCode.parse(uid), uid);
      expect(AccountCode.parse('  $uid  '), uid);
    });

    test('refuses a half-finished paste', () {
      expect(AccountCode.parse('kJ8sQ2mN'), isNull);
    });

    test('refuses something with a space in the middle of it', () {
      expect(AccountCode.parse('kJ8sQ2mNpR4t VwXyZa1bCd3e'), isNull);
    });

    test('refuses a sentence somebody pasted around it', () {
      expect(
        AccountCode.parse('my code is kJ8sQ2mNpR4tVwXyZa1bCd3e thanks'),
        isNull,
      );
    });

    test('refuses something far too long to be one', () {
      expect(AccountCode.parse('a' * 200), isNull);
    });

    test('and is not case folded, because a uid is not ours to fold', () {
      const String uid = 'kJ8sQ2mNpR4tVwXyZa1bCd3e';
      expect(AccountCode.parse(uid.toLowerCase()), uid.toLowerCase());
      expect(AccountCode.parse(uid), isNot(uid.toLowerCase()));
    });
  });
}
