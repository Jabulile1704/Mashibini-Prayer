import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';

import '../support/family_fixtures.dart';

/// Tying an account to a person (#76, ADR-023).
void main() {
  group('linking', () {
    test('it puts the account on the member, and nowhere else', () {
      final Family after = FamilyEditor.linkUid(
        familyOfFour(),
        memberId: mama.id,
        uid: 'uid-mama',
      );

      expect(after.membersById[mama.id]!.uid, 'uid-mama');
      expect(after.memberUids, <String>['uid-mama']);
      expect(after.members.where((Member m) => m.uid != null), hasLength(1));
    });

    test('memberUids grows as people sign in', () {
      Family family = familyOfFour();
      expect(family.memberUids, isEmpty, reason: 'nobody can sync yet');

      family = FamilyEditor.linkUid(
        family,
        memberId: jabulile.id,
        uid: 'uid-jabulile',
      );
      family = FamilyEditor.linkUid(family, memberId: tata.id, uid: 'uid-tata');

      expect(family.memberUids, <String>['uid-jabulile', 'uid-tata']);
    });

    test('signing in twice on the same phone is not an error', () {
      final Family once = FamilyEditor.linkUid(
        familyOfFour(),
        memberId: mama.id,
        uid: 'uid-mama',
      );
      final Family twice = FamilyEditor.linkUid(
        once,
        memberId: mama.id,
        uid: 'uid-mama',
      );

      expect(twice.members, once.members);
      expect(identical(twice, once), isTrue, reason: 'nothing to write');
    });

    test('nothing about the rota changes', () {
      final Family before = familyOfFour();
      final Family after = FamilyEditor.linkUid(
        before,
        memberId: mama.id,
        uid: 'uid-mama',
      );

      expect(after.cycles, before.cycles);
      expect(after.skips, before.skips);
    });
  });

  group('what it refuses', () {
    test('an account already belonging to somebody else', () {
      final Family taken = FamilyEditor.linkUid(
        familyOfFour(),
        memberId: mama.id,
        uid: 'uid-shared',
      );

      expect(
        () => FamilyEditor.linkUid(taken, memberId: tata.id, uid: 'uid-shared'),
        throwsArgumentError,
      );
    });

    test('and says whose it is, so the mistake is fixable', () {
      final Family taken = FamilyEditor.linkUid(
        familyOfFour(),
        memberId: mama.id,
        uid: 'uid-shared',
      );

      expect(
        () => FamilyEditor.linkUid(taken, memberId: tata.id, uid: 'uid-shared'),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message.toString(),
            'message',
            contains('Mama'),
          ),
        ),
      );
    });

    test('somebody who is not in the family', () {
      expect(
        () => FamilyEditor.linkUid(
          familyOfFour(),
          memberId: 'nobody',
          uid: 'uid-x',
        ),
        throwsArgumentError,
      );
    });

    test('an empty account id', () {
      expect(
        () =>
            FamilyEditor.linkUid(familyOfFour(), memberId: mama.id, uid: '   '),
        throwsArgumentError,
      );
    });
  });

  group('unlinking', () {
    test('it takes the account off, so another can be linked', () {
      Family family = FamilyEditor.linkUid(
        familyOfFour(),
        memberId: mama.id,
        uid: 'uid-oops',
      );
      family = FamilyEditor.unlinkUid(family, memberId: mama.id);

      expect(family.membersById[mama.id]!.uid, isNull);
      expect(family.memberUids, isEmpty);

      // And the account is free again.
      family = FamilyEditor.linkUid(family, memberId: tata.id, uid: 'uid-oops');
      expect(family.membersById[tata.id]!.uid, 'uid-oops');
    });

    test('it keeps everything else about the person', () {
      Family family = familyOfFour().copyWith(
        members: <Member>[
          jabulile,
          sisi,
          mama.copyWith(role: 'Mama', parentIds: <String>['m1']),
          tata,
        ],
      );
      family = FamilyEditor.linkUid(family, memberId: mama.id, uid: 'uid-mama');
      family = FamilyEditor.unlinkUid(family, memberId: mama.id);

      final Member after = family.membersById[mama.id]!;
      expect(after.role, 'Mama');
      expect(after.parentIds, <String>['m1']);
      expect(after.uid, isNull);
    });

    test('unlinking somebody who never signed in does nothing', () {
      final Family family = familyOfFour();
      expect(
        FamilyEditor.unlinkUid(family, memberId: mama.id).members,
        family.members,
      );
    });
  });

  group('who is this account', () {
    test('it finds them', () {
      final Family family = FamilyEditor.linkUid(
        familyOfFour(),
        memberId: sisi.id,
        uid: 'uid-sisi',
      );
      expect(FamilyEditor.memberFor(family, 'uid-sisi')?.id, sisi.id);
    });

    test('and says so plainly when it is nobody', () {
      expect(FamilyEditor.memberFor(familyOfFour(), 'uid-stranger'), isNull);
    });
  });
}
