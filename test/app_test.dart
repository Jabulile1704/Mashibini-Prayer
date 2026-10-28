import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';

import 'support/fake_id_generator.dart';
import 'support/fake_key_value_store.dart';

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

  group('MashibiniPrayerApp', () {
    testWidgets('builds and names itself', (WidgetTester tester) async {
      await tester.pumpWidget(
        MashibiniPrayerApp(
          repository: repository,
          settings: settings,
          journal: journal,
          ids: FakeIdGenerator(),
        ),
      );
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
          ids: FakeIdGenerator(),
        ),
      );

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('opens on the rota, not a placeholder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MashibiniPrayerApp(
          repository: repository,
          settings: settings,
          journal: journal,
          ids: FakeIdGenerator(),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing is set up yet, so the first thing a new install shows is the
      // invitation to set one up.
      expect(find.text('No rota yet'), findsOneWidget);
    });
  });
}
