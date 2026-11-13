import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/application/find_my_family.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';

import 'package:mashibini_prayer/src/data/sources/platform/identity.dart';

import '../support/fake_identity.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_remote_membership.dart';
import '../support/family_fixtures.dart';

/// A phone finding the family its account belongs to (#75).
void main() {
  late LocalFamilyRepository families;
  late FakeRemoteMembership memberships;
  late FakeIdentity identity;
  const SignedIn jabu = SignedIn(uid: 'uid-jabulile', displayName: 'Jabulile');
  late List<String> attached;
  late List<Object> trouble;

  FindMyFamily subject() => FindMyFamily(
    families: families,
    memberships: memberships,
    identity: identity,
    attachTo: (String familyId) async => attached.add(familyId),
    onTrouble: (Object error, StackTrace stack) => trouble.add(error),
  );

  setUp(() {
    families = LocalFamilyRepository(store: FakeKeyValueStore());
    memberships = FakeRemoteMembership();
    identity = FakeIdentity();
    attached = <String>[];
    trouble = <Object>[];
  });

  tearDown(() async => families.dispose());

  test('a phone nobody has signed in on asks nothing', () async {
    await families.save(familyOfFour());

    await subject()();

    expect(memberships.lookedUp, isEmpty);
    expect(memberships.byUid, isEmpty);
    expect(attached, isEmpty);
  });

  test('a phone with a family writes down which one', () async {
    await families.save(familyOfFour());
    identity = FakeIdentity(signedIn: jabu);

    await subject()();

    expect(memberships.byUid, <String, String>{jabu.uid: 'f1'});
  });

  test('and does not go looking for one it already has', () async {
    await families.save(familyOfFour());
    identity = FakeIdentity(signedIn: jabu);

    await subject()();

    expect(memberships.lookedUp, isEmpty);
    expect(attached, isEmpty);
  });

  test('a phone with nothing attaches to whatever it wrote down', () async {
    identity = FakeIdentity(signedIn: jabu);
    memberships.byUid[jabu.uid] = 'f1';

    await subject()();

    expect(attached, <String>['f1']);
  });

  test('an account that was never in a family attaches to nothing', () async {
    identity = FakeIdentity(signedIn: jabu);

    await subject()();

    expect(attached, isEmpty);
    expect(trouble, isEmpty);
  });

  test('a network that is not there is an ordinary morning', () async {
    identity = FakeIdentity(signedIn: jabu);
    memberships.failure = StateError('unavailable');

    await expectLater(subject()(), completes);
    expect(trouble, hasLength(1));
    expect(attached, isEmpty);
  });

  test('and the phone keeps what it had', () async {
    await families.save(familyOfFour());
    identity = FakeIdentity(signedIn: jabu);
    memberships.failure = StateError('unavailable');

    await subject()();

    expect((await families.load())!.name, 'Mashibini');
  });
}
