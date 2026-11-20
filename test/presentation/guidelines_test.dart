import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/photo_library_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/audio_library_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/presentation/brand/theme.dart';
import 'package:mashibini_prayer/src/data/sources/platform/identity.dart';
import 'package:mashibini_prayer/src/presentation/screens/phones_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/about_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/family_members_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/family_tree_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/home_shell.dart';
import 'package:mashibini_prayer/src/presentation/screens/journal_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/schedule_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/settings_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/setup_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/songbook_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/this_week_screen.dart';

import '../support/fake_app_version.dart';
import '../support/fake_identity.dart';
import '../support/fake_audio.dart';
import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_photos.dart';
import '../support/fake_reminders.dart';
import '../support/fake_sharing.dart';
import '../support/family_fixtures.dart';

/// The accessibility pass Day 13 did by hand, as four assertions that run on
/// every commit.
void main() {
  late LocalFamilyRepository family;
  late LocalDeviceSettingsRepository settings;
  late LocalJournalRepository journal;
  late FakeReminders reminders;

  setUp(() {
    final FakeKeyValueStore store = FakeKeyValueStore();
    family = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    journal = LocalJournalRepository(store: store, ids: FakeIdGenerator());
    reminders = FakeReminders();
  });

  tearDown(() async {
    await family.dispose();
    await settings.dispose();
    await journal.dispose();
  });

  Map<String, Widget> screens() => <String, Widget>{
    'This week': ThisWeekScreen(
      repository: family,
      settings: settings,
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'The weeks ahead': ScheduleScreen(
      familyRepository: family,
      settings: settings,
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'Journal': JournalScreen(journal: journal, today: () => anchor),
    'Settings': SettingsScreen(
      familyRepository: family,
      settings: settings,
      journal: journal,
      sharing: FakeSharing(),
      reminders: reminders,
      appVersion: FakeAppVersion(),
      identity: FakeIdentity(),
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'About, on a build that syncs': AboutScreen(
      appVersion: FakeAppVersion(),
      canSync: true,
    ),
    'About, on a build that does not': AboutScreen(
      appVersion: FakeAppVersion(),
      canSync: false,
    ),
    'Set up the rota': SetupScreen(
      familyRepository: family,
      settingsRepository: settings,
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'Who takes a week': FamilyMembersScreen(
      familyRepository: family,
      settings: settings,
      reminders: reminders,
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'Songs we love': SongbookScreen(
      familyRepository: family,
      settings: settings,
      audio: FakeAudio(),
      library: AudioLibraryRepository(store: FakeKeyValueStore()),
      photos: FakePhotos(),
      photoLibrary: PhotoLibraryRepository(store: FakeKeyValueStore()),
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    // Added with the screen rather than later: Day 31 recorded that a
    // sweep named "every screen" is one nobody re-reads the definition of,
    // and this sweep had never built the navigation bar for ADR-016 days.
    'The family\'s phones': PhonesScreen(
      familyRepository: family,
      identity: FakeIdentity(
        signedIn: const SignedIn(uid: 'kJ8sQ2mNpR4tVwXyZa1bCd3e'),
      ),
      sharing: FakeSharing(),
      join: null,
    ),
    'Family': FamilyTreeScreen(
      familyRepository: family,
      settings: settings,
      photos: FakePhotos(),
      photoLibrary: PhotoLibraryRepository(store: FakeKeyValueStore()),
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'The shell': HomeShell(
      repository: family,
      settings: settings,
      journal: journal,
      sharing: FakeSharing(),
      reminders: reminders,
      appVersion: FakeAppVersion(),
      identity: FakeIdentity(),
      audio: FakeAudio(),
      library: AudioLibraryRepository(store: FakeKeyValueStore()),
      photos: FakePhotos(),
      photoLibrary: PhotoLibraryRepository(store: FakeKeyValueStore()),
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
  };

  // Written out, and checked against the map by a test below (#157). It
  // cannot be derived: `screens()` needs repositories `setUp` has not built
  // when the test list is being collected.
  const List<String> everyScreen = <String>[
    'This week',
    'The weeks ahead',
    'Journal',
    'Settings',
    'About, on a build that syncs',
    'About, on a build that does not',
    'Set up the rota',
    'Who takes a week',
    'Songs we love',
    'The family\'s phones',
    'Family',
    'The shell',
  ];

  test('the list of screens is the map of screens', () {
    // The whole reason the list above is trustworthy. Add a screen to
    // either and this fails until it is in both.
    expect(screens().keys.toSet(), everyScreen.toSet());
    expect(
      everyScreen.length,
      everyScreen.toSet().length,
      reason: 'a name listed twice sweeps one screen and hides another',
    );
  });

  /// Pumps [screen] **with the app's real theme**.
  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drags each scrollable to the bottom, so the half of a long screen that
  /// a `ListView` has not built yet gets measured too.
  Future<void> scrollThrough(WidgetTester tester) async {
    final Finder scrollables = find.byType(Scrollable);
    for (int i = 0; i < scrollables.evaluate().length; i++) {
      for (int page = 0; page < 6; page++) {
        await tester.drag(scrollables.at(i), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
    }
  }

  Future<void> seed() async {
    await family.save(familyOfFour());
    await settings.saveYouAre(jabulile.id);
    await journal.write(
      date: anchor,
      text: 'A line written so the journal has something to lay out.',
      now: DateTime(2026, 10, 18, 9),
    );
  }

  group('every control is big enough to hit (N5)', () {
    for (final String name in everyScreen) {
      testWidgets('$name, with a rota', (WidgetTester tester) async {
        await seed();
        await pump(tester, screens()[name]!);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        await scrollThrough(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      });

      testWidgets('$name, with nothing stored', (WidgetTester tester) async {
        await pump(tester, screens()[name]!);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      });
    }
  });

  group('every control says what it is (N5)', () {
    for (final String name in everyScreen) {
      testWidgets(name, (WidgetTester tester) async {
        await seed();
        await pump(tester, screens()[name]!);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        await scrollThrough(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      });
    }
  });

  group('text is readable against what is behind it (N5)', () {
    for (final String name in everyScreen) {
      testWidgets(name, (WidgetTester tester) async {
        await seed();
        await pump(tester, screens()[name]!);
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await scrollThrough(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      });
    }
  });
}
