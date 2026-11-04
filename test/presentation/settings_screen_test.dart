import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/presentation/screens/about_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/settings_screen.dart';

import '../support/fake_app_version.dart';
import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_reminders.dart';
import '../support/family_fixtures.dart';

/// Day 19's screen, and the defect it exists to fix.
///
/// The one that matters most is the first group. Until this screen, "which
/// one are you" could be answered during setup and then — if answered wrongly
/// — never again: the only other place that asked hid itself as soon as it
/// had an answer. A phone that believes it belongs to Mama rings for Mama's
/// weeks, and the only cure was to rebuild the rota.
void main() {
  late LocalFamilyRepository family;
  late LocalDeviceSettingsRepository settings;
  late FakeReminders reminders;

  setUp(() {
    final FakeKeyValueStore store = FakeKeyValueStore();
    family = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    reminders = FakeReminders();
  });

  tearDown(() async {
    await family.dispose();
    await settings.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: SettingsScreen(
          familyRepository: family,
          settings: settings,
          reminders: reminders,
          appVersion: FakeAppVersion(),
          ids: FakeIdGenerator(),
          today: () => anchor,
          now: () => DateTime(2026, 10, 18, 9),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Brings a row into view. The list is longer than a test surface.
  Future<void> reveal(WidgetTester tester, Key row) async {
    await tester.scrollUntilVisible(find.byKey(row), 120);
    await tester.pumpAndSettle();
  }

  Future<void> tapRow(WidgetTester tester, Key row) async {
    await reveal(tester, row);
    await tester.tap(find.byKey(row));
    await tester.pumpAndSettle();
  }

  group('which one are you', () {
    testWidgets('says plainly that nobody has answered', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(find.text('Nobody has said yet'), findsOneWidget);
    });

    testWidgets('shows the name that was stored', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      await open(tester);

      expect(find.text('Mama'), findsOneWidget);
    });

    testWidgets('offers everyone in the rota, and can be changed', (
      WidgetTester tester,
    ) async {
      // The defect. Before Day 19 there was no screen in the app that would
      // let somebody change this answer once given.
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      await open(tester);

      await tapRow(tester, SettingsScreen.youAreRow);
      for (final String name in <String>['Jabulile', 'Sisi', 'Mama', 'Tata']) {
        expect(find.text(name), findsWidgets, reason: '$name is in the rota');
      }

      await tester.tap(find.text('Tata').last);
      await tester.pumpAndSettle();

      expect(await settings.loadYouAre(), tata.id);
      expect(find.text('Tata'), findsOneWidget);
    });

    testWidgets('changing it re-plans the reminders this phone holds', (
      WidgetTester tester,
    ) async {
      // The quiet half. Saving the new name without re-planning would leave
      // the phone ringing for the weeks of whoever it used to think it was.
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await settings.saveRemindersEnabled(enabled: true);
      await open(tester);

      await tapRow(tester, SettingsScreen.youAreRow);
      await tester.tap(find.text('Sisi').last);
      await tester.pumpAndSettle();

      // Sisi leads the week after Jabulile, so her reminder is a week later
      // than the one this phone was holding.
      expect(reminders.scheduled, isNotEmpty);
      expect(reminders.scheduled.first.turnStarts, anchor.addDays(7));
    });

    testWidgets('schedules nothing while reminders are off', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tapRow(tester, SettingsScreen.youAreRow);
      await tester.tap(find.text('Sisi').last);
      await tester.pumpAndSettle();

      expect(await settings.loadYouAre(), sisi.id);
      expect(reminders.scheduled, isEmpty, reason: 'R5.1: never asked');
    });

    testWidgets('cancelling keeps the stored answer', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      await open(tester);

      await tapRow(tester, SettingsScreen.youAreRow);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await settings.loadYouAre(), mama.id);
    });

    testWidgets('there is nothing to choose from before a rota exists', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('Set the rota up first'), findsWidgets);
      expect(
        tester.widget<ListTile>(find.byKey(SettingsScreen.youAreRow)).onTap,
        isNull,
      );
    });
  });

  group('reminders', () {
    testWidgets('off until asked, and asking requests permission', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await open(tester);

      await tester.tap(find.byKey(SettingsScreen.remindersRow));
      await tester.pumpAndSettle();

      expect(reminders.permissionRequests, 1);
      expect(await settings.loadRemindersEnabled(), isTrue);
      expect(reminders.scheduled, isNotEmpty);
    });

    testWidgets('a refusal is said out loud and nothing is stored', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      reminders.permissionGranted = false;
      await open(tester);

      await tester.tap(find.byKey(SettingsScreen.remindersRow));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('did not allow notifications'),
        findsOneWidget,
      );
      expect(await settings.loadRemindersEnabled(), isFalse);
    });

    testWidgets('switching off cancels what was scheduled', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await settings.saveRemindersEnabled(enabled: true);
      await open(tester);

      await tester.tap(find.byKey(SettingsScreen.remindersRow));
      await tester.pumpAndSettle();

      expect(reminders.cancelCount, 1);
      expect(await settings.loadRemindersEnabled(), isFalse);
    });

    testWidgets('when on, it says which reminder it is holding', (
      WidgetTester tester,
    ) async {
      // A reminder you cannot see is a reminder you cannot trust. The
      // Reminders screen listed three of these; one answers the question.
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await settings.saveRemindersEnabled(enabled: true);
      await open(tester);

      expect(find.textContaining('Next: the evening before'), findsOneWidget);
    });

    testWidgets('asks for a name first, rather than ringing for nobody', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveRemindersEnabled(enabled: true);
      await open(tester);

      expect(find.text('Say which one you are first'), findsOneWidget);
    });
  });

  group('appearance', () {
    testWidgets('follows the phone until chosen', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(find.text('Follow the phone'), findsOneWidget);
    });

    testWidgets('all three are offered, and the choice is stored', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tapRow(tester, SettingsScreen.appearanceRow);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(await settings.loadAppearance(), Appearance.dark);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('the current choice is ticked', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await settings.saveAppearance(Appearance.light);
      await open(tester);

      await tapRow(tester, SettingsScreen.appearanceRow);

      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('the rota', () {
    testWidgets('the turnover day is shown, because nothing else showed it', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await reveal(tester, SettingsScreen.turnoverRow);

      expect(find.textContaining('Sunday'), findsOneWidget);
    });

    testWidgets('it is not a control, and ADR-019 says why', (
      WidgetTester tester,
    ) async {
      // Changing the turnover weekday moves every week boundary the rota has
      // ever had, and `RotaEngine` refuses a family whose cycles no longer
      // begin on it — so a tappable row here would throw on the next frame
      // of This Week. It is a new epoch, not a setting (#100).
      await family.save(familyOfFour());
      await open(tester);
      await reveal(tester, SettingsScreen.turnoverRow);

      final ListTile row = tester.widget<ListTile>(
        find.byKey(SettingsScreen.turnoverRow),
      );
      expect(row.onTap, isNull);

      // Not disabled, though. `enabled: false` paints a ListTile at
      // `disabledColor` — 38% opacity, which composites to 2.42:1 against
      // the wax ground. This row states a fact; a fact nobody can read is
      // not a kindness. Found on a simulator, not by the contrast test,
      // which measures the palette rather than a widget's own treatment.
      expect(row.enabled, isTrue);
    });
  });

  group('about', () {
    testWidgets('carries the version, which used to sit on This Week', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await reveal(tester, SettingsScreen.aboutRow);

      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    });

    testWidgets('opens, and states the limits rather than omitting them', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tapRow(tester, SettingsScreen.aboutRow);

      expect(find.byType(AboutScreen), findsOneWidget);
      expect(find.byKey(AboutScreen.version), findsOneWidget);

      // Below the fold on a test surface, like the rest of the honest part.
      await tester.scrollUntilVisible(find.text('WHAT IT CANNOT DO YET'), 160);
      await tester.pumpAndSettle();

      expect(find.text('WHAT IT CANNOT DO YET'), findsOneWidget);
      expect(
        find.textContaining('do not see each other'),
        findsOneWidget,
        reason: 'the family should not have to read a repository to find out',
      );
    });
  });
}
