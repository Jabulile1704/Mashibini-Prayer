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
  // shared_preferences talks over a platform channel, so the binding has to
  // exist before anything reads storage.
  WidgetsFlutterBinding.ensureInitialized();

  // **Never fatal.** Signing in is the one thing that needs a configured
  // Firebase project; the rota, the journal, the tree and the songbook do
  // not. An exception escaping `main()` kills the app before `runApp` and
  // leaves the native launch screen on screen for ever — which is exactly
  // what shipped on Day 27, because `FirebaseIdentity` touched
  // `FirebaseAuth.instance` and this call was missing entirely.
  Identity identity = const NoIdentity();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    identity = FirebaseIdentity();
  } on Object catch (error) {
    debugPrint('Firebase did not start, so signing in is unavailable: $error');
  }

  // The whole dependency graph, in one place and in plain sight. This is the
  // "container" the architecture doc refers to: a constructor call, not a
  // framework.
  final PreferencesKeyValueStore store = PreferencesKeyValueStore();

  final LocalFamilyRepository repository = LocalFamilyRepository(
    store: store,
    onCorruptData: (Object error, StackTrace stack) {
      // Day 4 decided the repository hands corruption outward rather than
      // deciding what to do about it. For now that decision is: say so in the
      // log and carry on as if nothing were stored, which is what the screen
      // already renders. Reporting it properly belongs with error reporting,
      // and there is no issue for that yet because there is no reporter yet.
      debugPrint('Stored family could not be read: $error');
    },
  );

  final RandomIdGenerator ids = RandomIdGenerator();

  final LocalDeviceSettingsRepository settings = LocalDeviceSettingsRepository(
    store: store,
  );

  // Read before the first frame rather than streamed into it. The splash is
  // the first thing on screen, so a stream's asynchronous first value would
  // paint it in the wrong theme and then correct itself — a flash on every
  // cold start, for the sake of not awaiting one read.
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
