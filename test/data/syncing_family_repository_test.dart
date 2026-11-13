import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/syncing_family_repository.dart';
import 'package:mashibini_prayer/src/data/serialization/family_json.dart';
import 'package:mashibini_prayer/src/data/sources/remote/remote_family_source.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/skipped_turn.dart';

import '../support/fake_key_value_store.dart';
import '../support/fake_remote_family_source.dart';
import '../support/family_fixtures.dart';

/// The family on this phone and the family in the cloud (#75, R6.2).
void main() {
  late FakeKeyValueStore store;
  late LocalFamilyRepository onThisPhone;
  late FakeRemoteFamilySource remote;
  late SyncingFamilyRepository repository;
  late List<Object> trouble;
  late List<String> askedFor;

  setUp(() {
    store = FakeKeyValueStore();
    onThisPhone = LocalFamilyRepository(store: store);
    remote = FakeRemoteFamilySource();
    trouble = <Object>[];
    askedFor = <String>[];
    repository = SyncingFamilyRepository(
      local: onThisPhone,
      remoteFor: (String familyId) {
        askedFor.add(familyId);
        return remote;
      },
      onTrouble: (Object error, StackTrace stack) => trouble.add(error),
    );
  });

  tearDown(() async {
    await repository.dispose();
  });

  /// The same family, with one more person in it.
  Family withAnExtraPerson(Family family) => family.copyWith(
    members: <Member>[
      ...family.members,
      const Member(id: 'm5', displayName: 'Gogo'),
    ],
  );

  group('reading', () {
    test('answers from the phone, not the network', () async {
      await onThisPhone.save(familyOfFour());

      expect((await repository.load())!.name, 'Mashibini');
      expect(remote.pushed, isEmpty);
    });

    test('and starts listening to that family document', () async {
      await onThisPhone.save(familyOfFour());
      await repository.load();

      expect(askedFor, <String>['f1']);
      expect(remote.watchers, 1);
    });

    test('a phone with no family listens to nothing', () async {
      expect(await repository.load(), isNull);
      expect(askedFor, isEmpty);
    });

    test('watching is the phone watching itself', () async {
      remote.failOnPush = StateError('no signal');
      final List<Family?> seen = <Family?>[];
      final StreamSubscription<Family?> watching = repository.watch().listen(
        seen.add,
      );
      await settle();

      await repository.save(familyOfFour());
      await settle();
      await watching.cancel();

      // Nothing, then the family — and the network never came into it.
      expect(seen.map((Family? f) => f?.name).toList(), <String?>[
        null,
        'Mashibini',
      ]);
    });
  });

  group('writing', () {
    test('lands on the phone before it goes anywhere', () async {
      remote.failOnPush = StateError('no signal');

      await repository.save(familyOfFour());

      expect(await onThisPhone.load(), isNotNull);
      expect(trouble, hasLength(1));
    });

    test('a phone with no signal is not a failed save', () async {
      remote.failOnPush = StateError('no signal');

      await expectLater(repository.save(familyOfFour()), completes);
    });

    test('and then publishes it', () async {
      await repository.save(familyOfFour());

      expect(remote.pushed, hasLength(1));
      expect(remote.pushed.single.id, 'f1');
    });
  });

  group('something arrives', () {
    test('a phone with nothing takes it whole', () async {
      await repository.attachTo('f1');

      remote.arrive(familyOfFour());
      await settle();

      expect((await onThisPhone.load())!.name, 'Mashibini');
    });

    test('that is the reinstall, and it needs no merge', () async {
      await repository.attachTo('f1');

      remote.arrive(withAnExtraPerson(familyOfFour()));
      await settle();

      expect((await onThisPhone.load())!.members, hasLength(5));
    });

    test('what they know and we do not is kept', () async {
      await repository.save(familyOfFour());
      remote.pushed.clear();

      remote.arrive(withAnExtraPerson(familyOfFour()));
      await settle();

      expect((await onThisPhone.load())!.members, hasLength(5));
    });

    test('what we know and they do not is handed back', () async {
      await repository.save(withAnExtraPerson(familyOfFour()));
      remote.pushed.clear();

      remote.arrive(familyOfFour());
      await settle();

      expect(remote.pushed, hasLength(1));
      expect(remote.pushed.single.members, hasLength(5));
    });

    test('our own write coming back changes nothing', () async {
      final Family family = familyOfFour(
        skips: <SkippedTurn>[
          SkippedTurn(id: 's1', weekStart: anchor, memberId: 'm1'),
        ],
      );
      await repository.save(family);
      remote.pushed.clear();

      // Whatever we published is what the document now holds, so this is
      // the echo every write produces.
      remote.arrive(remote.stored);
      await settle();

      expect(remote.pushed, isEmpty, reason: 'an echo must not echo back');
    });

    test('and it settles rather than ringing', () async {
      await repository.save(withAnExtraPerson(familyOfFour()));
      remote.pushed.clear();

      // Two phones, each holding half of the answer, each publishing.
      remote.arrive(familyOfFour());
      await settle();
      remote.arrive(remote.stored);
      await settle();
      remote.arrive(remote.stored);
      await settle();

      expect(
        remote.pushed,
        hasLength(1),
        reason: 'one correction, then silence',
      );
    });

    test('a different family is refused rather than merged', () async {
      await repository.save(familyOfFour());

      remote.arrive(
        Family(
          id: 'f2',
          name: 'Somebody else',
          members: const <Member>[jabulile, sisi],
          cycles: <Cycle>[
            Cycle(
              id: 'c1',
              effectiveFrom: anchor,
              order: const <String>['m1', 'm2'],
            ),
          ],
        ),
      );
      await settle();

      expect((await onThisPhone.load())!.name, 'Mashibini');
      expect(trouble.single, isA<StateError>());
    });

    test('an empty document is not an instruction to forget', () async {
      await repository.save(familyOfFour());

      remote.arrive(null);
      await settle();

      expect(await onThisPhone.load(), isNotNull);
    });
  });

  group('attaching', () {
    test('asks for the same family only once', () async {
      await repository.attachTo('f1');
      await repository.attachTo('f1');

      expect(askedFor, <String>['f1']);
      expect(remote.cancelled, 0);
    });

    test('moving to another family lets go of the first', () async {
      await repository.attachTo('f1');
      await repository.attachTo('f2');

      expect(askedFor, <String>['f1', 'f2']);
      expect(remote.cancelled, 1);
    });

    test('clearing lets go', () async {
      await repository.save(familyOfFour());
      await repository.clear();

      expect(remote.cancelled, 1);
      expect(await onThisPhone.load(), isNull);
    });

    test('and nothing arrives after dispose', () async {
      await repository.attachTo('f1');
      await repository.dispose();

      expect(remote.cancelled, 1);
    });
  });

  group('the document is the one the rules were written for', () {
    test('what is published is what FamilyJson writes', () async {
      final Family family = familyOfFour();
      await repository.save(family);

      expect(FamilyJson.toMap(remote.pushed.single), FamilyJson.toMap(family));
      expect(FamilyJson.toMap(family)['memberUids'], isA<List<String>>());
    });
  });

  group('the seam', () {
    test('a remote source is still only three methods', () {
      // If this stops compiling, something has grown that the Firestore
      // implementation now has to carry, and `FirestoreFamilySource` is
      // meant to stay too small to hide a bug in.
      final RemoteFamilySource source = FakeRemoteFamilySource();
      expect(source.fetch, isNotNull);
      expect(source.push, isNotNull);
      expect(source.watch, isNotNull);
    });
  });
}
