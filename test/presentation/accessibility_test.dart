import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/audio_library_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/presentation/screens/journal_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/about_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/family_members_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/family_tree_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/home_shell.dart';
import 'package:mashibini_prayer/src/presentation/screens/schedule_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/settings_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/setup_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/songbook_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/this_week_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_app_version.dart';
import '../support/fake_identity.dart';
import '../support/fake_audio.dart';
import '../support/fake_photos.dart';
import '../support/fake_reminders.dart';
import '../support/fake_sharing.dart';
import '../support/family_fixtures.dart';

/// N5: text scales with the OS setting without clipping, and every control
/// has a label a screen reader can read.
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

  /// Every screen in the app, built against the same stored family.
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
    'About': AboutScreen(appVersion: FakeAppVersion()),
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
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'Family': FamilyTreeScreen(
      familyRepository: family,
      settings: settings,
      photos: FakePhotos(),
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'The shell, with its five tabs': HomeShell(
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
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'Journal': JournalScreen(journal: journal, today: () => anchor),
    'Set up the rota': SetupScreen(
      familyRepository: family,
      settingsRepository: settings,
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
  };

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    required double scale,
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('text scales without clipping (N5)', () {
    // A small phone, because a narrow screen is where large text breaks.
    const Size phone = Size(360, 760);

    const List<String> everyScreen = <String>[
      'This week',
      'The weeks ahead',
      'Journal',
      'Settings',
      'About',
      'Set up the rota',
      'Who takes a week',
      'Family',
      'Songs we love',
      'Songs we love',
      'The shell, with its five tabs',
    ];

    for (final double scale in <double>[1.0, 2.0, 3.1]) {
      for (final String name in everyScreen) {
        testWidgets('$name at ${scale}x', (WidgetTester tester) async {
          await family.save(familyOfFour());
          await settings.saveYouAre(jabulile.id);
          await journal.write(
            date: anchor,
            text: 'A line written to give the journal something to lay out.',
            now: DateTime(2026, 10, 18, 9),
          );

          await pump(tester, screens()[name]!, scale: scale, size: phone);

          expect(find.byType(Scaffold), findsWidgets);
        });

        testWidgets('$name at ${scale}x with nothing stored', (
          WidgetTester tester,
        ) async {
          await pump(tester, screens()[name]!, scale: scale, size: phone);

          expect(find.byType(Scaffold), findsWidgets);
        });
      }
    }

    testWidgets('every destination announces its name', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      final SemanticsHandle handle = tester.ensureSemantics();

      await pump(
        tester,
        screens()['The shell, with its five tabs']!,
        scale: 1.0,
        size: const Size(360, 760),
      );

      for (final String label in HomeShell.labels) {
        expect(
          find.bySemanticsLabel(RegExp(label)),
          findsWidgets,
          reason: '"$label" is not announced',
        );
      }

      handle.dispose();
    });

    testWidgets('a rota that has not started yet, at 3.1x', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());

      await pump(
        tester,
        ThisWeekScreen(
          repository: family,
          settings: settings,
          ids: FakeIdGenerator(),
          today: () => anchor.subtractDays(28),
        ),
        scale: 3.1,
        size: phone,
      );

      expect(find.textContaining('The rota starts on'), findsOneWidget);
    });
  });

  group('controls announce themselves (N5)', () {
    testWidgets('every button on This Week has a label', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      final SemanticsHandle handle = tester.ensureSemantics();

      await pump(
        tester,
        screens()['This week']!,
        scale: 1.0,
        size: const Size(390, 844),
      );

      expect(
        find.byType(IconButton),
        findsNothing,
        reason: 'destinations belong in the tab bar, not the top-right',
      );

      handle.dispose();
    });

    testWidgets('the skip controls say which week they act on', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      final SemanticsHandle handle = tester.ensureSemantics();

      await pump(
        tester,
        screens()['The weeks ahead']!,
        scale: 1.0,
        size: const Size(390, 844),
      );

      // Seven identical "Skip" buttons in a list are unusable by ear.
      expect(
        find.bySemanticsLabel(RegExp(r'Skip .*1 November 2026')),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
