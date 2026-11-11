import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/audio_library_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/presentation/screens/home_shell.dart';
import 'package:mashibini_prayer/src/presentation/widgets/comb_bar.dart';
import 'package:mashibini_prayer/src/presentation/screens/settings_screen.dart';

import '../support/fake_photos.dart';
import '../support/fake_app_version.dart';
import '../support/fake_identity.dart';
import '../support/fake_audio.dart';
import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_reminders.dart';
import '../support/fake_sharing.dart';
import '../support/family_fixtures.dart';

/// The five destinations of ADR-016, ADR-020 and ADR-022.
void main() {
  late LocalFamilyRepository family;
  late LocalDeviceSettingsRepository settings;
  late LocalJournalRepository journal;

  setUp(() {
    final FakeKeyValueStore store = FakeKeyValueStore();
    family = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    journal = LocalJournalRepository(store: store, ids: FakeIdGenerator());
  });

  tearDown(() async {
    await family.dispose();
    await settings.dispose();
    await journal.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: HomeShell(
          repository: family,
          settings: settings,
          journal: journal,
          sharing: FakeSharing(),
          reminders: FakeReminders(),
          appVersion: FakeAppVersion(),
          identity: FakeIdentity(),
          audio: FakeAudio(),
          library: AudioLibraryRepository(store: FakeKeyValueStore()),
          photos: FakePhotos(),
          ids: FakeIdGenerator(),
          today: () => anchor,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label).first);
    await tester.pumpAndSettle();
  }

  /// Brings a Settings row into view before touching it.
  Future<void> reveal(WidgetTester tester, Key row) async {
    await tester.scrollUntilVisible(
      find.byKey(row),
      120,
      scrollable: find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the five destinations', () {
    testWidgets('the four around the edge carry a visible word', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      for (final String tab in <String>[
        'Ahead',
        'Journal',
        'Family',
        'Settings',
      ]) {
        expect(find.text(tab), findsWidgets, reason: '$tab should be a tab');
      }
    });

    testWidgets('each label is one word, so none of them wraps', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      for (final CombDestination destination in HomeShell.destinations) {
        expect(
          destination.label.trim().split(RegExp(r'\s+')),
          anyOf(hasLength(1), hasLength(2)),
          reason: '"${destination.label}" is too long for a fifth of a bar',
        );
      }
      // The only two-word one is the centre, which draws no text at all.
      expect(
        HomeShell.destinations
            .where((CombDestination d) => d.label.contains(' '))
            .map((CombDestination d) => d.label),
        <String>['This week'],
      );
      expect(
        find.descendant(
          of: find.byKey(HomeShell.bar),
          matching: find.text('This week'),
        ),
        findsNothing,
      );
    });

    testWidgets('the centre is This week, raised and unlabelled', (
      WidgetTester tester,
    ) async {
      // The app answers one question, and the bar should look like it does.
      await family.save(familyOfFour());
      await open(tester);

      expect(HomeShell.destinations[HomeShell.centre].label, 'This week');
      // Said to a screen reader even though it is not drawn.
      expect(find.bySemanticsLabel('This week'), findsWidgets);
    });

    testWidgets('it opens on This week', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(find.text('Jabulile'), findsWidgets);
    });

    testWidgets('each tab shows its own screen', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await open(tester);

      await tapTab(tester, 'Ahead');
      expect(find.text('The weeks ahead'), findsWidgets);

      await tapTab(tester, 'Journal');
      expect(find.textContaining('Nothing written yet'), findsOneWidget);

      await tapTab(tester, 'Family');
      expect(find.textContaining('Everyone in the family sees'), findsWidgets);

      await tapTab(tester, 'Settings');
      expect(find.text('Which one are you?'), findsOneWidget);

      await tapTab(tester, 'This week');
      expect(find.text('Jabulile'), findsWidgets);
    });

    testWidgets('there are exactly five, with the middle one raised', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      final CombBar bar = tester.widget<CombBar>(find.byKey(HomeShell.bar));
      expect(bar.destinations, hasLength(5));
      expect(bar.centreIndex, 2);
      expect(
        bar.centreIndex,
        (bar.destinations.length - 1) ~/ 2,
        reason: 'the raised cell must be in the middle',
      );
    });
  });

  group('switching tabs', () {
    testWidgets('a tab keeps its state while another is looked at', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await journal.write(
        date: anchor,
        text: 'An entry to find again.',
        now: DateTime(2026, 10, 19, 9),
      );
      await open(tester);

      await tapTab(tester, 'Journal');
      expect(find.textContaining('An entry to find again'), findsOneWidget);

      await tapTab(tester, 'This week');
      await tapTab(tester, 'Journal');

      expect(find.textContaining('An entry to find again'), findsOneWidget);
    });

    testWidgets('every tab is built, so none of them flashes empty', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(find.byType(IndexedStack), findsOneWidget);
    });
  });

  group('what Settings absorbed', () {
    testWidgets('reminders are a switch here, not a screen behind a bell', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await tapTab(tester, 'Settings');

      expect(find.byKey(SettingsScreen.remindersRow), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(SettingsScreen.remindersRow))
            .value,
        isFalse,
        reason: 'a phone that has not been asked sends nothing (R5.1)',
      );
    });

    testWidgets('setup is reachable again, after confirming', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await tapTab(tester, 'Settings');
      await reveal(tester, SettingsScreen.startAgainRow);

      await tester.tap(find.byKey(SettingsScreen.startAgainRow));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SettingsScreen.confirmStartAgain));
      await tester.pumpAndSettle();

      expect(find.text('Whose week is it?'), findsOneWidget);
    });

    testWidgets('declining leaves the rota alone', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await open(tester);
      await tapTab(tester, 'Settings');
      await reveal(tester, SettingsScreen.startAgainRow);

      await tester.tap(find.byKey(SettingsScreen.startAgainRow));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(find.text('Whose week is it?'), findsNothing);
      expect((await family.load())!.members, hasLength(4));
    });

    testWidgets('the version moved off This Week and into Settings', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await tapTab(tester, 'Settings');
      await reveal(tester, SettingsScreen.aboutRow);

      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    });
  });
}
