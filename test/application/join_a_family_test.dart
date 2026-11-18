import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/application/join_a_family.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/syncing_family_repository.dart';
import 'package:mashibini_prayer/src/data/sources/platform/identity.dart';
import 'package:mashibini_prayer/src/data/sources/remote/remote_family_source.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';

import '../support/fake_identity.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_remote_family_source.dart';
import '../support/fake_remote_membership.dart';
import '../support/family_fixtures.dart';

/// A second phone being let into a family (#143, ADR-027).
void main() {
  const SignedIn sisiAccount = SignedIn(uid: 'uid-sisi', displayName: 'Sisi');

  /// A valid family code: `f` and eleven characters of the alphabet.
  const String theirCode = 'fqx7n2bkrmdh';

  late FakeKeyValueStore store;
  late LocalFamilyRepository onThisPhone;
  late SyncingFamilyRepository repository;
  late LocalDeviceSettingsRepository settings;
  late FakeRemoteMembership memberships;
  late FakeIdentity identity;
  late Map<String, FakeRemoteFamilySource> remotes;

  /// The family as the other phone published it: Jabulile signed in, and
  /// Sisi already admitted, which is what makes the document readable here.
  Family theirFamily({String id = theirCode}) => Family(
    id: id,
    name: 'Mashibini',
    members: <Member>[
      jabulile.copyWith(uid: 'uid-jabulile'),
      sisi.copyWith(uid: sisiAccount.uid),
      mama,
      tata,
    ],
    cycles: <Cycle>[
      Cycle(
        id: 'c1',
        effectiveFrom: anchor,
        order: const <String>['m1', 'm2', 'm3', 'm4'],
      ),
    ],
  );

  FakeRemoteFamilySource remoteFor(String familyId) =>
      remotes.putIfAbsent(familyId, () => FakeRemoteFamilySource());

  JoinAFamily subject() => JoinAFamily(
    families: repository,
    settings: settings,
    memberships: memberships,
    identity: identity,
    remoteFor: remoteFor,
  );

  setUp(() {
    store = FakeKeyValueStore();
    onThisPhone = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    memberships = FakeRemoteMembership();
    identity = FakeIdentity(signedIn: sisiAccount);
    remotes = <String, FakeRemoteFamilySource>{};
    repository = SyncingFamilyRepository(
      local: onThisPhone,
      remoteFor: remoteFor,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await settings.dispose();
  });

  group('before anything is asked of the network', () {
    test(
      'a phone nobody signed in on cannot be admitted to anything',
      () async {
        identity = FakeIdentity();

        expect(await subject()(theirCode), isA<NotSignedIn>());
        expect(remotes, isEmpty);
      },
    );

    test('a code no generator could have made is not asked about', () async {
      expect(await subject()('f1'), isA<NotAFamilyCode>());
      expect(remotes, isEmpty, reason: 'a typo must not cost a round trip');
    });
  });

  group('joining', () {
    test('takes the family whole', () async {
      remoteFor(theirCode).stored = theirFamily();

      final JoinResult result = await subject()(theirCode);

      expect(result, isA<Joined>());
      expect((await onThisPhone.load())!.id, theirCode);
      expect((await onThisPhone.load())!.members, hasLength(4));
    });

    test('writes down which family, so a reinstall finds it', () async {
      remoteFor(theirCode).stored = theirFamily();

      await subject()(theirCode);

      expect(memberships.byUid, <String, String>{'uid-sisi': theirCode});
    });

    test('and the phone is now listening to that document', () async {
      remoteFor(theirCode).stored = theirFamily();

      await subject()(theirCode);

      expect(remoteFor(theirCode).watchers, 1);
    });

    test('however the person typed it', () async {
      remoteFor(theirCode).stored = theirFamily();

      expect(await subject()('FQX7-N2BK-RMDH'), isA<Joined>());
      expect((await onThisPhone.load())!.id, theirCode);
    });
  });

  group('not yours yet', () {
    test('a refusal is one answer, not two', () async {
      // Firestore cannot tell "no such family" from "not in it", and
      // ADR-027 says it must not: otherwise a family id is worth guessing.
      remoteFor(theirCode).failOnFetch = const RemoteRefused();

      expect(await subject()(theirCode), isA<NotYourFamilyYet>());
    });

    test('an empty document is the same answer', () async {
      expect(await subject()(theirCode), isA<NotYourFamilyYet>());
    });

    test('and nothing on this phone is touched', () async {
      await onThisPhone.save(familyOfFour());
      remoteFor(theirCode).failOnFetch = const RemoteRefused();

      await subject()(theirCode, replacing: true);

      expect((await onThisPhone.load())!.id, 'f1');
      expect(memberships.byUid, isEmpty);
    });
  });

  group('a phone that already has a rota', () {
    setUp(() async {
      await onThisPhone.save(familyOfFour());
      await settings.saveYouAre('m1');
      remoteFor(theirCode).stored = theirFamily();
    });

    test('is asked first, and told what it is giving up', () async {
      final JoinResult result = await subject()(theirCode);

      expect(result, isA<WouldReplaceThisRota>());
      expect((result as WouldReplaceThisRota).mine.name, 'Mashibini');
      expect((await onThisPhone.load())!.id, 'f1');
    });

    test('nothing is fetched until it has answered', () async {
      await subject()(theirCode);

      expect(remoteFor(theirCode).watchers, 0);
    });

    test('and joins once it has', () async {
      expect(await subject()(theirCode, replacing: true), isA<Joined>());
      expect((await onThisPhone.load())!.id, theirCode);
    });

    test('forgetting who this phone belonged to', () async {
      // `m1` was a member of the rota being put aside. In the new family it
      // is either nobody or, worse, somebody else.
      await subject()(theirCode, replacing: true);

      expect(await settings.loadYouAre(), isNull);
    });

    test('rejoining the family it is already in asks nothing', () async {
      await subject()(theirCode, replacing: true);
      await settings.saveYouAre('m2');

      expect(await subject()(theirCode), isA<Joined>());
      expect(
        await settings.loadYouAre(),
        'm2',
        reason: 'this is the same family, so the answer still holds',
      );
    });
  });

  group('the network', () {
    test('not answering changes nothing and says so', () async {
      remoteFor(theirCode).failOnFetch = StateError('unavailable');

      final JoinResult result = await subject()(theirCode);

      expect(result, isA<CouldNotAsk>());
      expect(await onThisPhone.load(), isNull);
      expect(memberships.byUid, isEmpty);
    });
  });
}
