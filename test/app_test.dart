import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/photo_library_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/audio_library_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';

import 'support/fake_id_generator.dart';
import 'support/fake_key_value_store.dart';
import 'support/fake_photos.dart';
import 'support/fake_app_version.dart';
import 'support/fake_identity.dart';
import 'support/fake_audio.dart';
import 'support/fake_reminders.dart';
import 'support/fake_sharing.dart';

void main() {
  late LocalFamilyRepository repository;
  late LocalDeviceSettingsRepository settings;
  late LocalJournalRepository journal;

  setUp(() {
    final FakeKeyValueStore store = FakeKeyValueStore();
    repository = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    journal = LocalJournalRepository(store: store, ids: FakeIdGenerator());
  });

  tearDown(() async {
    await repository.dispose();
    await settings.dispose();
    await journal.dispose();
  });

  /// What `MaterialApp` was given, which is what decides the theme.
  ThemeMode? themeMode(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

  group('MashibiniPrayerApp', () {
    testWidgets('builds and names itself', (WidgetTester tester) async {
      await tester.pumpWidget(
        MashibiniPrayerApp(
          repository: repository,
          settings: settings,
          journal: journal,
          sharing: FakeSharing(),
          reminders: FakeReminders(),
          appVersion: FakeAppVersion(),
          identity: FakeIdentity(),
          audio: FakeAudio(),
          library: AudioLibraryRepository(store: FakeKeyValueStore()),
          photos: FakePhotos(),
          photoLibrary: PhotoLibraryRepository(store: FakeKeyValueStore()),
          ids: FakeIdGenerator(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Mashibini Prayer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides the debug banner', (WidgetTester tester) async {
      await tester.pumpWidget(
        MashibiniPrayerApp(
          repository: repository,
          settings: settings,
          journal: journal,
          sharing: FakeSharing(),
          reminders: FakeReminders(),
          appVersion: FakeAppVersion(),
          identity: FakeIdentity(),
          audio: FakeAudio(),
          library: AudioLibraryRepository(store: FakeKeyValueStore()),
          photos: FakePhotos(),
          photoLibrary: PhotoLibraryRepository(store: FakeKeyValueStore()),
          ids: FakeIdGenerator(),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('follows the phone until somebody chooses otherwise', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MashibiniPrayerApp(
          repository: repository,
          settings: settings,
          journal: journal,
          sharing: FakeSharing(),
          reminders: FakeReminders(),
          appVersion: FakeAppVersion(),
          identity: FakeIdentity(),
          audio: FakeAudio(),
          library: AudioLibraryRepository(store: FakeKeyValueStore()),
          photos: FakePhotos(),
          photoLibrary: PhotoLibraryRepository(store: FakeKeyValueStore()),
          ids: FakeIdGenerator(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(themeMode(tester), ThemeMode.system);
    });

    testWidgets('opens in the theme that was stored, without a flash', (
      WidgetTester tester,
    ) async {
      await settings.saveAppearance(Appearance.dark);

      await tester.pumpWidget(
        MashibiniPrayerApp(
          repository: repository,
          settings: settings,
          journal: journal,
          sharing: FakeSharing(),
          reminders: FakeReminders(),
          appVersion: FakeAppVersion(),
          identity: FakeIdentity(),
          audio: FakeAudio(),
          library: AudioLibraryRepository(store: FakeKeyValueStore()),
          photos: FakePhotos(),
          photoLibrary: PhotoLibraryRepository(store: FakeKeyValueStore()),
          ids: FakeIdGenerator(),
          initialAppearance: await settings.loadAppearance(),
        ),
      );

      // The *first* frame, before anything has settled.
      await tester.pump();
      expect(themeMode(tester), ThemeMode.dark);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(themeMode(tester), ThemeMode.dark);
    });

    testWidgets('a change reaches the whole app, not just the row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MashibiniPrayerApp(
          repository: repository,
          settings: settings,
          journal: journal,
          sharing: FakeSharing(),
          reminders: FakeReminders(),
          appVersion: FakeAppVersion(),
          identity: FakeIdentity(),
          audio: FakeAudio(),
          library: AudioLibraryRepository(store: FakeKeyValueStore()),
          photos: FakePhotos(),
          photoLibrary: PhotoLibraryRepository(store: FakeKeyValueStore()),
          ids: FakeIdGenerator(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await settings.saveAppearance(Appearance.light);
      await tester.pumpAndSettle();

      expect(themeMode(tester), ThemeMode.light);
    });

    testWidgets('opens on the rota, not a placeholder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MashibiniPrayerApp(
          repository: repository,
          settings: settings,
          journal: journal,
          sharing: FakeSharing(),
          reminders: FakeReminders(),
          appVersion: FakeAppVersion(),
          identity: FakeIdentity(),
          audio: FakeAudio(),
          library: AudioLibraryRepository(store: FakeKeyValueStore()),
          photos: FakePhotos(),
          photoLibrary: PhotoLibraryRepository(store: FakeKeyValueStore()),
          ids: FakeIdGenerator(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('No rota yet'), findsOneWidget);
    });
  });
}
