import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/migrations/the_family_needs_its_own_id.dart';
import 'package:mashibini_prayer/src/data/random_id_generator.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/data/serialization/family_json.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

/// A family created before #148 is called `f1`, and so is everybody
/// else's.
void main() {
  late FakeKeyValueStore store;

  setUp(() => store = FakeKeyValueStore());

  Future<void> storeFamily(Family family) =>
      store.write(LocalFamilyRepository.storageKey, FamilyJson.encode(family));

  Future<Family?> stored() async {
    final String? raw = store.values[LocalFamilyRepository.storageKey];
    return raw == null ? null : FamilyJson.decode(raw);
  }

  Family named(String id) => Family(
    id: id,
    name: familyOfFour().name,
    members: familyOfFour().members,
    cycles: familyOfFour().cycles,
  );

  Future<void> run() =>
      TheFamilyNeedsItsOwnId.run(store: store, ids: FakeIdGenerator());

  test('a family called f1 is given one of its own', () async {
    await storeFamily(named('f1'));

    await run();

    expect((await stored())!.id, 'f-1');
  });

  test('and keeps everything else about itself', () async {
    await storeFamily(familyOfFour());

    await run();

    final Family after = (await stored())!;
    expect(after.name, 'Mashibini');
    expect(after.members, familyOfFour().members);
    expect(after.cycles.single.id, 'c1');
    expect(after.schemaVersion, familyOfFour().schemaVersion);
  });

  test('a family whose id came from the generator is left alone', () async {
    await storeFamily(named('fqx7n2bkrmdh'));

    await run();

    expect((await stored())!.id, 'fqx7n2bkrmdh');
  });

  test('a family this phone joined is left alone', () async {
    // Somebody else's id. Renaming it would detach this phone from the
    // family it belongs to, which is worse than the bug being fixed.
    await storeFamily(named('f2'));

    await run();

    expect((await stored())!.id, 'f2');
  });

  test('a phone with no family is left alone', () async {
    await run();

    expect(store.values[LocalFamilyRepository.storageKey], isNull);
  });

  test('a document that cannot be read is not rewritten', () async {
    await store.write(LocalFamilyRepository.storageKey, 'not json at all{');

    await expectLater(run(), completes);
    expect(store.values[LocalFamilyRepository.storageKey], 'not json at all{');
  });

  test('running it twice does not rename twice', () async {
    await storeFamily(named('f1'));

    await run();
    final String once = (await stored())!.id;
    await TheFamilyNeedsItsOwnId.run(store: store, ids: FakeIdGenerator());

    expect((await stored())!.id, once);
  });

  group('the id it hands out', () {
    test('is unique between two phones that have never met', () {
      final RandomIdGenerator a = RandomIdGenerator();
      final RandomIdGenerator b = RandomIdGenerator();

      final Set<String> ids = <String>{
        for (int i = 0; i < 500; i++) a.newId('f'),
        for (int i = 0; i < 500; i++) b.newId('f'),
      };

      expect(ids, hasLength(1000));
    });

    test('and is not the one the hardcode produced', () {
      expect(
        RandomIdGenerator().newId('f'),
        isNot(TheFamilyNeedsItsOwnId.hardcoded),
      );
    });
  });
}
