import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/application/find_my_family.dart';
import 'src/data/random_id_generator.dart';
import 'src/data/repositories/device_settings_repository.dart';
import 'src/data/repositories/journal_repository.dart';
import 'src/data/migrations/photo_paths_off_the_family.dart';
import 'src/data/repositories/local_family_repository.dart';
import 'src/data/repositories/photo_library_repository.dart';
import 'src/data/repositories/family_repository.dart';
import 'src/data/repositories/syncing_family_repository.dart';
import 'src/data/sources/remote/firestore_family_source.dart';
import 'src/data/sources/remote/remote_membership.dart';
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
  FirebaseFirestore? firestore;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    identity = FirebaseIdentity();
    firestore = FirebaseFirestore.instance;
  } on Object catch (error) {
    debugPrint('Firebase did not start, so signing in is unavailable: $error');
  }

  final PreferencesKeyValueStore store = PreferencesKeyValueStore();

  final PhotoLibraryRepository photoLibrary = PhotoLibraryRepository(
    store: store,
  );

  // Before anything reads the family: a photograph chosen by an older build
  // is recorded on the member, which is where it must not be once the
  // document syncs (#140).
  await PhotoPathsOffTheFamily.run(store: store, photos: photoLibrary);

  final LocalFamilyRepository onThisPhone = LocalFamilyRepository(
    store: store,
    onCorruptData: (Object error, StackTrace stack) {
      debugPrint('Stored family could not be read: $error');
    },
  );

  // Without Firebase the app is exactly what it was: one phone, one rota,
  // no network anywhere in the read path (#75, R6.1).
  SyncingFamilyRepository? syncing;
  FindMyFamily? findMyFamily;
  if (firestore case final FirebaseFirestore db) {
    syncing = SyncingFamilyRepository(
      local: onThisPhone,
      remoteFor: (String familyId) =>
          FirestoreFamilySource(familyId: familyId, firestore: db),
      onTrouble: (Object error, StackTrace stack) {
        debugPrint('The family did not sync: $error');
      },
    );
    findMyFamily = FindMyFamily(
      families: syncing,
      memberships: FirestoreMembership(firestore: db),
      identity: identity,
      attachTo: syncing.attachTo,
      onTrouble: (Object error, StackTrace stack) {
        debugPrint('Could not look up which family this account is in: $error');
      },
    );
    await findMyFamily();
  }

  final FamilyRepository repository = syncing ?? onThisPhone;

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
      photoLibrary: photoLibrary,
      whenSignedIn: findMyFamily?.call,
      identity: identity,
      audio: PlatformAudio(),
      library: AudioLibraryRepository(store: store),
      reminders: LocalReminders(),
      appVersion: const PlatformAppVersion(),
      ids: ids,
    ),
  );
}
