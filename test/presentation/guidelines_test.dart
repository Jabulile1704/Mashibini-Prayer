import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/audio_library_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/presentation/brand/theme.dart';
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
///
/// Three things in this project have been promised and not measured:
///
/// - **`Touch.minimum`**'s own doc comment has said "Day 22's accessibility
///   pass will measure against it" since Day 17. Nothing ever did.
/// - **Contrast** is measured by `contrast_test.dart`, but only as the
///   *palette* — pairs of colours from `Palette`.
/// - **Every control has a name.** Asserted screen by screen, never swept.
///
/// Flutter ships matchers for all three, working on **rendered pixels**
/// rather than on the source.
///
/// ## What this does not catch, measured rather than assumed
///
/// The first draft of this file claimed `textContrastGuideline` "would have
/// caught Day 19". **It would not.** Reintroducing that defect on purpose —
/// `enabled: false` on the turnover row — and scrolling it into view, the
/// matcher passed. Written down because the claim was nearly committed, one
/// day after #111 was withdrawn for exactly the same reason: believing what
/// a test ought to measure instead of checking what it does.
///
/// The disabled-treatment gap is closed in `contrast_test.dart` instead, by
/// asserting `ThemeData.disabledColor` against the surfaces it is painted
/// on. That check fails when it should; this one does not.
///
/// It also only sees **what is painted**. A `ListView` does not build below
/// the fold, so on a long screen most of it is never measured — Settings'
/// turnover row is not even constructed at 390×844. Every screen here is
/// therefore scrolled to the bottom and measured again.
///
/// A note on the font: widget tests render with a fixed-width placeholder,
/// which made #111's width measurements meaningless. It does not affect
/// these — contrast is a property of colour, and a tap target's size comes
/// from its box rather than its glyphs.
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
    'About': AboutScreen(appVersion: FakeAppVersion()),
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
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
  };

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
    'The shell',
  ];

  /// Pumps [screen] **with the app's real theme**.
  ///
  /// The sweep in `accessibility_test.dart` does not, which is defensible
  /// there — it is looking for overflow, and a layout breaks the same way in
  /// any theme. Here the theme *is* the subject: a contrast matcher run
  /// against Flutter's defaults would be measuring somebody else's colours.
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
  ///
  /// `drag` rather than `scrollUntilVisible`, because there is no particular
  /// widget being looked for — the point is to reach everything.
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
    // 48dp on Android, 44pt on iOS. `Touch.minimum` is 48, which is the
    // stricter of the two, so both are asserted rather than only the one
    // the token happens to match.
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
    // Samples the pixels a `Text` is painted over, so it sees combinations
    // the palette test never pairs up. It does **not** see a disabled
    // `ListTile` — see the note at the top of this file — so it is a second
    // net rather than the one that catches Day 19's defect.
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
