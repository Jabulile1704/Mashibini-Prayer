import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/presentation/screens/journal_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/reminders_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/schedule_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/setup_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/this_week_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_app_version.dart';
import '../support/fake_reminders.dart';
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
      journal: journal,
      reminders: reminders,
      appVersion: FakeAppVersion(),
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'The weeks ahead': ScheduleScreen(
      familyRepository: family,
      settings: settings,
      ids: FakeIdGenerator(),
      today: () => anchor,
    ),
    'Reminders': RemindersScreen(
      familyRepository: family,
      settings: settings,
      reminders: reminders,
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
      'Reminders',
      'Journal',
      'Set up the rota',
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
          // only proves the screen actually built something.
          expect(find.byType(Scaffold), findsOneWidget);
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

          expect(find.byType(Scaffold), findsOneWidget);
        });
      }
    }

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
          journal: journal,
          reminders: reminders,
          appVersion: FakeAppVersion(),
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

      // Icon-only buttons are the risk: without a tooltip they announce as
      // "button" and nothing else.
      for (final String label in <String>[
        'Journal',
        'Reminders',
        'The weeks ahead',
      ]) {
        expect(
          find.bySemanticsLabel(label),
          findsWidgets,
          reason: 'an icon button with no label is a button nobody can use',
        );
      }

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
