import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/data/sources/local/preferences_key_value_store.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/family_fixtures.dart';

/// The one file in `lib/src/data` that talks to a package rather than to our
/// own abstraction, so it is the one place where a wiring mistake — a wrong
/// key, a value written but never read back — would pass every other test in
/// the suite and still lose the family's rota.
///
/// Tested against `InMemorySharedPreferencesAsync`, which is the package's own
/// implementation of its own interface. That is deliberately different from
/// mocking a vendor SDK into a shape we invented: nothing here encodes a guess
/// about how `shared_preferences` behaves.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('PreferencesKeyValueStore', () {
    test('a key that was never written reads as null', () async {
      final PreferencesKeyValueStore store = PreferencesKeyValueStore();

      expect(await store.read('nothing-here'), isNull);
    });

    test('what is written comes back', () async {
      final PreferencesKeyValueStore store = PreferencesKeyValueStore();

      await store.write('k', 'a value');

      expect(await store.read('k'), 'a value');
    });

    test('writing again replaces rather than appends', () async {
      final PreferencesKeyValueStore store = PreferencesKeyValueStore();

      await store.write('k', 'first');
      await store.write('k', 'second');

      expect(await store.read('k'), 'second');
    });

    test('delete removes it, and deleting nothing is harmless', () async {
      final PreferencesKeyValueStore store = PreferencesKeyValueStore();
      await store.write('k', 'v');

      await store.delete('k');
      expect(await store.read('k'), isNull);

      await expectLater(store.delete('k'), completes);
    });

    test('keys do not collide', () async {
      final PreferencesKeyValueStore store = PreferencesKeyValueStore();

      await store.write('a', '1');
      await store.write('b', '2');

      expect(await store.read('a'), '1');
      expect(await store.read('b'), '2');
    });

    test(
      'a value with newlines and quotes survives — JSON lives here',
      () async {
        final PreferencesKeyValueStore store = PreferencesKeyValueStore();
        const String awkward = '{"note":"line one\nline \\"two\\"","n":1}';

        await store.write('k', awkward);

        expect(await store.read('k'), awkward);
      },
    );
  });

  group('what an app restart looks like', () {
    test('a new store instance sees what the previous one wrote', () async {
      await PreferencesKeyValueStore().write('k', 'written before restart');

      // A fresh object over the same platform storage: the app, reopened.
      expect(
        await PreferencesKeyValueStore().read('k'),
        'written before restart',
      );
    });

    test(
      'a family saved before a restart still computes the same rota',
      () async {
        final LocalFamilyRepository before = LocalFamilyRepository(
          store: PreferencesKeyValueStore(),
        );
        await before.save(familyOfFour());
        await before.dispose();

        final LocalFamilyRepository after = LocalFamilyRepository(
          store: PreferencesKeyValueStore(),
        );
        addTearDown(after.dispose);

        final Family? reloaded = await after.load();

        expect(reloaded, isNotNull, reason: 'the rota must survive a restart');
        expect(reloaded!.name, 'Mashibini');
        expect(reloaded.members, hasLength(4));

        final RotaEngine engine = RotaEngine.forFamily(reloaded);
        for (int week = 0; week < 8; week++) {
          expect(
            engine.turnOn(anchor.addDays(week * 7))!.leader,
            RotaEngine.forFamily(familyOfFour())
                .turnOn(anchor.addDays(week * 7))!
                .leader,
            reason: 'week $week differs after a restart',
          );
        }
      },
    );

    test('clearing before a restart leaves nothing behind', () async {
      final LocalFamilyRepository before = LocalFamilyRepository(
        store: PreferencesKeyValueStore(),
      );
      await before.save(familyOfFour());
      await before.clear();
      await before.dispose();

      final LocalFamilyRepository after = LocalFamilyRepository(
        store: PreferencesKeyValueStore(),
      );
      addTearDown(after.dispose);

      expect(await after.load(), isNull);
    });
  });
}
