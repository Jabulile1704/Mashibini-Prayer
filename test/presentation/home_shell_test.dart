import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/presentation/screens/home_shell.dart';
import 'package:mashibini_prayer/src/presentation/screens/settings_screen.dart';

import '../support/fake_app_version.dart';
import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_reminders.dart';
import '../support/family_fixtures.dart';

/// The four tabs of ADR-016.
///
/// Before Day 18 every destination was a `Navigator.push` from This Week,
/// three of them from unlabelled icons in the top-right. These tests are
/// mostly about the thing that replaced them being reachable and staying
/// put.
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
          reminders: FakeReminders(),
          appVersion: FakeAppVersion(),
          ids: FakeIdGenerator(),
          today: () => anchor,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Brings a Settings row into view before touching it.
  ///
  /// Day 19 gave Settings enough rows to scroll, and a `ListView` does not
  /// build what is below the fold — so a finder for an off-screen row reports
  /// it missing rather than off-screen. Scrolling the right `Scrollable`
  /// matters too: `IndexedStack` builds all four tabs, so there are four of
  /// them in the tree at once.
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

  group('the four destinations', () {
    testWidgets('every one is reachable, and labelled in words', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      // The labels are *visible*, which is the part that matters. Day 13
      // gave the old icons screen-reader names; a name does not make an
      // unlabelled icon discoverable to somebody looking at the screen.
      for (final String tab in <String>[
        'This week',
        'Weeks ahead',
        'Journal',
        'Settings',
      ]) {
        expect(find.text(tab), findsWidgets, reason: '$tab should be a tab');
      }
    });

    testWidgets('each tab shows its own screen', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(find.text('Jabulile'), findsWidgets);

      await tapTab(tester, 'Weeks ahead');
      expect(find.text('The weeks ahead'), findsWidgets);

      await tapTab(tester, 'Journal');
      expect(find.textContaining('Nothing written yet'), findsOneWidget);

      await tapTab(tester, 'Settings');
      expect(find.text('Which one are you?'), findsOneWidget);
    });

    testWidgets('there are exactly four, which ADR-016 calls the ceiling', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(
        tester
            .widget<NavigationBar>(find.byKey(HomeShell.bar))
            .destinations
            .length,
        4,
      );
    });
  });

  group('switching tabs', () {
    testWidgets('a tab keeps its state while another is looked at', (
      WidgetTester tester,
    ) async {
      // The reason for IndexedStack rather than swapping the body. Somebody
      // part-way down their journal who checks whose week it is should come
      // back to where they were, not to the top.
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
      // IndexedStack builds all four. That is the cost of keeping state,
      // and it is why switching does not re-read storage.
      await family.save(familyOfFour());
      await open(tester);

      expect(find.byType(IndexedStack), findsOneWidget);
    });
  });

  group('what Settings absorbed', () {
    testWidgets('reminders are a switch here, not a screen behind a bell', (
      WidgetTester tester,
    ) async {
      // Day 18 put a chevron here that opened a screen holding one switch.
      // Day 19 folded that screen in: the switch is the row.
      await family.save(familyOfFour());
      await open(tester);
      await tapTab(tester, 'Settings');

      expect(find.byKey(SettingsScreen.remindersRow), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(
          find.byKey(SettingsScreen.remindersRow),
        ).value,
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

      // Exactly one. The first version of this test asserted the version
      // was *absent* while This Week was showing, and it failed — because
      // IndexedStack builds every tab, so "not visible" is not "not in the
      // tree". It was also finding a second copy: Settings had gained the
      // version line while This Week had not yet lost it.
      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    });
  });
}
