import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/data/random_id_generator.dart';
import 'src/data/repositories/device_settings_repository.dart';
import 'src/data/repositories/journal_repository.dart';
import 'src/data/repositories/local_family_repository.dart';
import 'src/data/sources/local/preferences_key_value_store.dart';
import 'src/data/sources/notifications/local_reminders.dart';
import 'src/data/sources/platform/app_version.dart';
import 'src/data/repositories/audio_library_repository.dart';
import 'src/data/sources/platform/audio.dart';
import 'src/data/sources/platform/identity.dart';
import 'src/data/sources/platform/photos.dart';
import 'src/data/sources/platform/sharing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Identity identity = const NoIdentity();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    identity = FirebaseIdentity();
  } on Object catch (error) {
    debugPrint('Firebase did not start, so signing in is unavailable: $error');
  }

  final PreferencesKeyValueStore store = PreferencesKeyValueStore();

  final LocalFamilyRepository repository = LocalFamilyRepository(
    store: store,
    onCorruptData: (Object error, StackTrace stack) {
      debugPrint('Stored family could not be read: $error');
    },
  );

  final RandomIdGenerator ids = RandomIdGenerator();

  final LocalDeviceSettingsRepository settings = LocalDeviceSettingsRepository(
    store: store,
  );

  final Appearance appearance = await settings.loadAppearance();

  runApp(
    MashibiniPrayerApp(
      repository: repository,
      settings: settings,
      initialAppearance: appearance,
      journal: LocalJournalRepository(store: store, ids: ids),
      sharing: const PlatformSharing(),
      photos: const PlatformPhotos(),
      identity: identity,
      audio: PlatformAudio(),
      library: AudioLibraryRepository(store: store),
      reminders: LocalReminders(),
      appVersion: const PlatformAppVersion(),
      ids: ids,
    ),
  );
}
