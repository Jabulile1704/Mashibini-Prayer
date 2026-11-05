import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
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
import 'package:mashibini_prayer/src/presentation/screens/this_week_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_app_version.dart';
import '../support/fake_reminders.dart';
import '../support/fake_sharing.dart';
import '../support/family_fixtures.dart';

/// N5: text scales with the OS setting without clipping, and every control
/// has a label a screen reader can read.
///
/// The clipping half is checked by pumping every screen at the largest text
/// setting either platform offers. Flutter reports an overflow as a thrown
/// error, so a laid-out-wrong screen fails here rather than being noticed by
/// somebody holding the phone.
///
/// iOS goes to roughly 3.1x at AX5 and Android to 2.0x. Both are tested: a
/// layout that survives 2.0 can still break at 3.1, and a family member who
/// needs AX5 is exactly who this requirement is for.
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
    'Family': FamilyTreeScreen(familyRepository: family, today: () => anchor),
    // The shell rather than a screen, because the thing being measured here
    // is the **navigation bar**: five destinations, five visible labels,
    // across 360pt. ADR-016 put the ceiling at four on the judgement that
    // five is where a bottom bar stops working on a phone, and ADR-020
    // reversed it — so the claim had to stop being a judgement and start
    // being a test. Nothing else in this sweep built the bar at all.
    'The shell, with its five tabs': HomeShell(
      repository: family,
      settings: settings,
      journal: journal,
      sharing: FakeSharing(),
      reminders: reminders,
      appVersion: FakeAppVersion(),
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

    // Named here rather than read from screens(), which cannot be called
    // until setUp has built the repositories.
    const List<String> everyScreen = <String>[
      'This week',
      'The weeks ahead',
      'Journal',
      'Settings',
      'About',
      'Set up the rota',
      'Who takes a week',
      'Family',
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

          // Reaching here without a thrown overflow is the assertion; this
          // only proves the screen actually built something. `findsWidgets`
          // rather than `findsOneWidget` because the shell nests a Scaffold
          // inside its tabs' own — the count was never the point.
          expect(find.byType(Scaffold), findsWidgets);
        });

        // The empty states are tested separately because they are a
        // different layout, not a smaller one: a centred column with nothing
        // to scroll. The first version of this sweep seeded data before
        // pumping and therefore never rendered one — and the overflow it
        // missed was found by hand, on a simulator at AX5.
        testWidgets('$name at ${scale}x with nothing stored', (
          WidgetTester tester,
        ) async {
          await pump(tester, screens()[name]!, scale: scale, size: phone);

          expect(find.byType(Scaffold), findsWidgets);
        });
      }
    }

    // ──────────────────────── the tab labels (#111) ────────────────────────
    //
    // A **characterisation test**: it records a defect rather than forbidding
    // one, with the numbers, because the fix is a naming decision that is not
    // the developer's to make. If the labels or the tab count change, this
    // fails and has to be updated — which is the point. It is the only thing
    // in the suite that can see the problem at all.
    //
    // `NavigationBar` gives each label a cell of `width / destinations` and
    // clips anything wider with `TextOverflow.clip`. Clipping **throws
    // nothing**, sets no flag, and leaves the whole string in the widget
    // tree. Three assertions were tried before one could fail:
    //
    //  1. `findsOneWidget` on the label — passes on "Settin".
    //  2. `RenderParagraph.didExceedMaxLines` — always false, because no
    //     `maxLines` is set. Proved by renaming a tab to "Family hierarchy
    //     and the whole honeycomb of everybody" and watching it pass.
    //  3. `getMinIntrinsicWidth` against the cell — the width of the longest
    //     unbreakable word, which wrapping cannot help. This one fails.
    //
    // What it found: **"Settings" has been cut off on every phone narrower
    // than about 430pt since Day 18**, at ordinary text size, through four
    // releases. Day 21's fifth tab takes it from one clipped label to three.
    for (final double width in <double>[360, 390, 430]) {
      testWidgets('which tab labels are cut off at ${width}pt', (
        WidgetTester tester,
      ) async {
        await family.save(familyOfFour());
        await pump(
          tester,
          screens()['The shell, with its five tabs']!,
          scale: 1.0,
          size: Size(width, 760),
        );

        final List<String> clipped = <String>[];
        for (final String label in HomeShell.labels) {
          final RenderParagraph paragraph = tester
              .renderObject<RenderParagraph>(
                find.descendant(
                  of: find.byKey(HomeShell.bar),
                  matching: find.text(label),
                ),
              );
          if (paragraph.getMinIntrinsicWidth(double.infinity) >
              paragraph.size.width) {
            clipped.add(label);
          }
        }

        expect(
          clipped,
          switch (width) {
            360 => <String>['Journal', 'Family', 'Settings'],
            390 => <String>['Journal', 'Settings'],
            _ => <String>['Journal', 'Settings'],
          },
          reason:
              'the set of cut-off tab labels at ${width}pt has changed — if '
              'this is the fix for #111, update it; if it is a new label, '
              'it does not fit',
        );
      });
    }

    testWidgets('a label is announced in full however little of it is drawn', (
      WidgetTester tester,
    ) async {
      // The one mercy in the current state: a screen reader is given the
      // whole word, so the defect is visual only. Asserted so that a fix
      // which hides the labels cannot also lose this.
      await family.save(familyOfFour());
      final SemanticsHandle handle = tester.ensureSemantics();

      await pump(
        tester,
        screens()['The shell, with its five tabs']!,
        scale: 1.0,
        size: const Size(360, 760),
      );

      for (final String label in HomeShell.labels) {
        // A pattern, not the whole string: a destination announces itself as
        // "This week, Tab 1 of 5", so an exact match finds nothing and would
        // read as "no label" when the label is there.
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
      // Stored, but ahead of time: a third state, and the only one that
      // renders "The rota starts on".
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

      // There are none left to check. Day 18 moved every destination into
      // the bottom navigation bar, whose labels are *visible* rather than
      // only announced — which is the better fix for the problem this test
      // was written about, so the test now asserts their absence.
      //
      // The tabs themselves are covered in home_shell_test.dart.
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
