import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/random_id_generator.dart';
import 'src/data/repositories/device_settings_repository.dart';
import 'src/data/repositories/journal_repository.dart';
import 'src/data/repositories/local_family_repository.dart';
import 'src/data/sources/local/preferences_key_value_store.dart';
import 'src/data/sources/notifications/local_reminders.dart';
import 'src/data/sources/platform/app_version.dart';

void main() {
  // shared_preferences talks over a platform channel, so the binding has to
  // exist before anything reads storage.
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    MashibiniPrayerApp(
      repository: repository,
      settings: LocalDeviceSettingsRepository(store: store),
      journal: LocalJournalRepository(store: store, ids: ids),
      reminders: LocalReminders(),
      appVersion: const PlatformAppVersion(),
      ids: ids,
    ),
  );
}
