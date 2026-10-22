import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';

import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

void main() {
  late FakeKeyValueStore store;
  late LocalFamilyRepository repository;
  late List<Object> reportedCorruption;

  setUp(() {
    store = FakeKeyValueStore();
    reportedCorruption = <Object>[];
    repository = LocalFamilyRepository(
      store: store,
      onCorruptData: (Object error, StackTrace stack) =>
          reportedCorruption.add(error),
    );
  });

  tearDown(() async => repository.dispose());

  group('an empty device', () {
    test('has no family, which is an answer and not a failure', () async {
      expect(await repository.load(), isNull);
      expect(reportedCorruption, isEmpty);
    });
  });

  group('saving and loading', () {
    test('what was saved is what comes back', () async {
      await repository.save(familyOfFour());

      final Family? loaded = await repository.load();

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Mashibini');
      expect(loaded.members, hasLength(4));
      expect(RotaEngine.forFamily(loaded).turnOn(anchor)!.leader, jabulile);
    });

    test('survives a new repository over the same store', () async {
      await repository.save(familyOfFour());

      // As if the app had been closed and opened again.
      final LocalFamilyRepository reopened = LocalFamilyRepository(
        store: store,
      );
      addTearDown(reopened.dispose);

      expect((await reopened.load())!.name, 'Mashibini');
    });

    test('saving twice overwrites rather than accumulating', () async {
      await repository.save(familyOfFour());
      await repository.save(familyOfFour().copyWith(name: 'Mashibini House'));

      expect((await repository.load())!.name, 'Mashibini House');
      expect(store.values, hasLength(1));
    });

    test('clear removes it', () async {
      await repository.save(familyOfFour());
      await repository.clear();

      expect(await repository.load(), isNull);
      expect(store.values, isEmpty);
    });
  });

  group('reading needs no connection (R6.1)', () {
    test('loading touches the store and nothing else', () async {
      await repository.save(familyOfFour());
      store.readCount = 0;

      await repository.load();

      // One read of local storage is the entire cost of answering the
      // question. There is no network call available to this class: nothing
      // it imports can make one.
      expect(store.readCount, 1);
    });
  });

  group('corrupt storage', () {
    test('does not crash the app, and is reported outward', () async {
      store.values[LocalFamilyRepository.storageKey] = '{ not json';

      expect(await repository.load(), isNull);
      expect(reportedCorruption, hasLength(1));
      expect(reportedCorruption.single, isA<FormatException>());
    });

    test('a half-written family is treated as corrupt, not as empty', () async {
      store.values[LocalFamilyRepository.storageKey] =
          '{"id":"f1","name":"Mashibini"}';

      expect(await repository.load(), isNull);
      expect(reportedCorruption, hasLength(1));
    });

    test('with no reporter it still refuses to crash', () async {
      final LocalFamilyRepository quiet = LocalFamilyRepository(store: store);
      addTearDown(quiet.dispose);
      store.values[LocalFamilyRepository.storageKey] = 'rubbish';

      expect(await quiet.load(), isNull);
    });

    test('a failing store is not swallowed', () async {
      store.failOnRead = StateError('disk is on fire');

      await expectLater(repository.load(), throwsStateError);
      // Not corruption: the data was never read, so nothing was corrupt.
      expect(reportedCorruption, isEmpty);
    });
  });

  group('watching', () {
    test('a listener gets the current value first', () async {
      await repository.save(familyOfFour());

      expect((await repository.watch().first)!.name, 'Mashibini');
    });

    test('a listener on an empty device gets null first', () async {
      expect(await repository.watch().first, isNull);
    });

    test('emits on save and on clear', () async {
      final List<String?> seen = <String?>[];
      final Stream<Family?> changes = repository.watch();
      final StreamSubscription<Family?> subscription = changes.listen(
        (Family? family) => seen.add(family?.name),
      );
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await repository.save(familyOfFour());
      await pumpEventQueue();
      await repository.save(familyOfFour().copyWith(name: 'Second'));
      await pumpEventQueue();
      await repository.clear();
      await pumpEventQueue();

      expect(seen, <String?>[null, 'Mashibini', 'Second', null]);
    });

    test('two listeners both get everything', () async {
      final List<String?> first = <String?>[];
      final List<String?> second = <String?>[];
      final StreamSubscription<Family?> a = repository.watch().listen(
        (Family? f) => first.add(f?.name),
      );
      final StreamSubscription<Family?> b = repository.watch().listen(
        (Family? f) => second.add(f?.name),
      );
      addTearDown(a.cancel);
      addTearDown(b.cancel);

      await pumpEventQueue();
      await repository.save(familyOfFour());
      await pumpEventQueue();

      expect(first, <String?>[null, 'Mashibini']);
      expect(second, <String?>[null, 'Mashibini']);
    });
  });

  group('after dispose', () {
    test('using it is a programming error, not a silent no-op', () async {
      await repository.dispose();

      expect(() => repository.save(familyOfFour()), throwsStateError);
      expect(() => repository.watch().first, throwsStateError);
      expect(repository.clear, throwsStateError);
    });

    test('disposing twice is harmless', () async {
      await repository.dispose();
      await expectLater(repository.dispose(), completes);
    });
  });
}
