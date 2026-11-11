import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';

import '../support/fake_key_value_store.dart';

void main() {
  late FakeKeyValueStore store;
  late LocalDeviceSettingsRepository settings;

  setUp(() {
    store = FakeKeyValueStore();
    settings = LocalDeviceSettingsRepository(store: store);
  });

  tearDown(() async => settings.dispose());

  test('nobody has said who this phone belongs to', () async {
    expect(await settings.loadYouAre(), isNull);
  });

  test('remembers who you are', () async {
    await settings.saveYouAre('m2');

    expect(await settings.loadYouAre(), 'm2');
  });

  test('saving null forgets rather than storing the word null', () async {
    await settings.saveYouAre('m2');

    await settings.saveYouAre(null);

    expect(await settings.loadYouAre(), isNull);
    expect(store.values, isEmpty);
  });

  test('survives a new repository over the same store', () async {
    await settings.saveYouAre('m3');

    final LocalDeviceSettingsRepository reopened =
        LocalDeviceSettingsRepository(store: store);
    addTearDown(reopened.dispose);

    expect(await reopened.loadYouAre(), 'm3');
  });

  test('watching gets the current value first, then changes', () async {
    await settings.saveYouAre('m1');
    final List<String?> seen = <String?>[];
    final subscription = settings.watchYouAre().listen(seen.add);
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    await settings.saveYouAre('m4');
    await pumpEventQueue();
    await settings.saveYouAre(null);
    await pumpEventQueue();

    expect(seen, <String?>['m1', 'm4', null]);
  });

  test('using it after dispose is a programming error', () async {
    await settings.dispose();

    expect(() => settings.saveYouAre('m1'), throwsStateError);
    expect(() => settings.watchYouAre().first, throwsStateError);
  });

  group('appearance', () {
    test('follows the phone until somebody says otherwise', () async {
      expect(await settings.loadAppearance(), Appearance.system);
    });

    test('remembers a choice', () async {
      await settings.saveAppearance(Appearance.dark);

      expect(await settings.loadAppearance(), Appearance.dark);
    });

    test('is stored as a word, not a position', () async {
      await settings.saveAppearance(Appearance.light);

      expect(
        store.values[LocalDeviceSettingsRepository.appearanceKey],
        'light',
      );
    });

    test('a word this build does not know falls back to the phone', () async {
      await store.write(LocalDeviceSettingsRepository.appearanceKey, 'sepia');

      expect(await settings.loadAppearance(), Appearance.system);
    });

    test('survives a new repository over the same store', () async {
      await settings.saveAppearance(Appearance.dark);

      final LocalDeviceSettingsRepository reopened =
          LocalDeviceSettingsRepository(store: store);
      addTearDown(reopened.dispose);

      expect(await reopened.loadAppearance(), Appearance.dark);
    });

    test('watching gets the current value first, then changes', () async {
      await settings.saveAppearance(Appearance.light);
      final List<Appearance> seen = <Appearance>[];
      final subscription = settings.watchAppearance().listen(seen.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      await settings.saveAppearance(Appearance.dark);
      await pumpEventQueue();

      expect(seen, <Appearance>[Appearance.light, Appearance.dark]);
    });

    test('using it after dispose is a programming error', () async {
      await settings.dispose();

      expect(() => settings.saveAppearance(Appearance.dark), throwsStateError);
    });
  });

  test('disposing twice is harmless', () async {
    await settings.dispose();
    await expectLater(settings.dispose(), completes);
  });
}
