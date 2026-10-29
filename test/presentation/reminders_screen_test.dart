import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/presentation/screens/reminders_screen.dart';

import '../support/fake_key_value_store.dart';
import '../support/fake_reminders.dart';
import '../support/family_fixtures.dart';

void main() {
  late LocalFamilyRepository family;
  late LocalDeviceSettingsRepository settings;
  late FakeReminders reminders;

  final DateTime before = DateTime(2026, 10, 17, 8);

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
        home: RemindersScreen(
          familyRepository: family,
          settings: settings,
          reminders: reminders,
          today: () => anchor,
          now: () => before,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('nothing until asked (R5.1)', () {
    testWidgets('the switch starts off', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);

      await open(tester);

      expect(
        tester.widget<SwitchListTile>(find.byKey(RemindersScreen.toggle)).value,
        isFalse,
      );
    });

    testWidgets('opening the screen asks for no permission and schedules '
        'nothing', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);

      await open(tester);

      expect(reminders.permissionRequests, 0);
      expect(reminders.scheduled, isEmpty);
    });
  });

  group('switching it on', () {
    testWidgets("asks permission, then schedules this person's turns", (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(sisi.id);
      await open(tester);

      await tester.tap(find.byKey(RemindersScreen.toggle));
      await tester.pumpAndSettle();

      expect(reminders.permissionRequests, 1);
      expect(reminders.scheduled, isNotEmpty);
      expect(await settings.loadRemindersEnabled(), isTrue);
    });

    testWidgets('a refused permission schedules nothing and explains', (
      WidgetTester tester,
    ) async {
      reminders.permissionGranted = false;
      await family.save(familyOfFour());
      await settings.saveYouAre(sisi.id);
      await open(tester);

      await tester.tap(find.byKey(RemindersScreen.toggle));
      await tester.pumpAndSettle();

      expect(reminders.scheduled, isEmpty);
      expect(await settings.loadRemindersEnabled(), isFalse);
      expect(
        find.textContaining('did not allow notifications'),
        findsOneWidget,
      );
    });

    testWidgets('with nobody saying which one you are, nothing is scheduled', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(RemindersScreen.toggle));
      await tester.pumpAndSettle();

      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('the screen says it cannot reach anybody else', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(
        find.textContaining('cannot send anything to anyone else'),
        findsOneWidget,
      );
    });
  });

  group('switching it off', () {
    testWidgets('cancels everything pending', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(sisi.id);
      await open(tester);

      await tester.tap(find.byKey(RemindersScreen.toggle));
      await tester.pumpAndSettle();
      expect(reminders.scheduled, isNotEmpty);

      await tester.tap(find.byKey(RemindersScreen.toggle));
      await tester.pumpAndSettle();

      expect(reminders.scheduled, isEmpty);
      expect(await settings.loadRemindersEnabled(), isFalse);
    });
  });

  group('what it shows', () {
    testWidgets('lists the turns it will remind you about', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await open(tester);

      await tester.tap(find.byKey(RemindersScreen.toggle));
      await tester.pumpAndSettle();

      expect(find.textContaining('Your week starting'), findsWidgets);
    });

    testWidgets('says so plainly when there is nothing to show', (
      WidgetTester tester,
    ) async {
      // In the rota, but standing well before it begins: the engine has no
      // turn to offer, so there is honestly nothing to list.
      await family.save(familyOfFour());
      await settings.saveYouAre(tata.id);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocales.delegates,
          supportedLocales: AppLocales.supported,
          locale: const Locale('en', 'ZA'),
          home: RemindersScreen(
            familyRepository: family,
            settings: settings,
            reminders: reminders,
            today: () => anchor.subtractDays(70),
            now: () => DateTime(2026, 8, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(RemindersScreen.toggle));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Nothing to remind you about'),
        findsOneWidget,
      );
    });
  });

  group('saying which one you are', () {
    testWidgets('the picker appears only when nobody has said', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      expect(find.byKey(RemindersScreen.youArePicker), findsOneWidget);

      await settings.saveYouAre(mama.id);
      await tester.pumpAndSettle();
      expect(find.byKey(RemindersScreen.youArePicker), findsNothing);
    });

    testWidgets('choosing a name is remembered on this phone', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(RemindersScreen.youArePicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mama').last);
      await tester.pumpAndSettle();

      expect(await settings.loadYouAre(), mama.id);
    });

    testWidgets('choosing after switching on schedules without a second tap', (
      WidgetTester tester,
    ) async {
      // The order somebody is most likely to do it in: reach for the switch
      // first, discover the phone does not know who they are, then say.
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(RemindersScreen.toggle));
      await tester.pumpAndSettle();
      expect(reminders.scheduled, isEmpty);

      await tester.tap(find.byKey(RemindersScreen.youArePicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sisi').last);
      await tester.pumpAndSettle();

      expect(reminders.scheduled, isNotEmpty);
      expect(find.textContaining('Your week starting'), findsWidgets);
    });

    testWidgets('choosing while switched off schedules nothing', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(RemindersScreen.youArePicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sisi').last);
      await tester.pumpAndSettle();

      expect(reminders.scheduled, isEmpty);
      expect(reminders.permissionRequests, 0);
    });

    testWidgets('it offers the people currently in the rota', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(RemindersScreen.youArePicker));
      await tester.pumpAndSettle();

      for (final String name in <String>['Jabulile', 'Sisi', 'Mama', 'Tata']) {
        expect(find.text(name), findsWidgets);
      }
    });
  });
}
