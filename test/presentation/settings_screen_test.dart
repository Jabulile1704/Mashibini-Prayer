import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';
import 'package:mashibini_prayer/src/data/sources/platform/identity.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';
import 'package:mashibini_prayer/src/presentation/screens/about_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/family_members_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/settings_screen.dart';

import '../support/fake_app_version.dart';
import '../support/fake_identity.dart';
import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_reminders.dart';
import '../support/fake_sharing.dart';
import '../support/family_fixtures.dart';

/// Day 19's screen, and the defect it exists to fix.
void main() {
  late LocalFamilyRepository family;
  late LocalDeviceSettingsRepository settings;
  late FakeReminders reminders;
  late FakeSharing sharing;
  late FakeIdentity identity;
  late LocalJournalRepository journal;

  setUp(() {
    final FakeKeyValueStore store = FakeKeyValueStore();
    family = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    reminders = FakeReminders();
    sharing = FakeSharing();
    identity = FakeIdentity();
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
        home: SettingsScreen(
          familyRepository: family,
          settings: settings,
          journal: journal,
          sharing: sharing,
          reminders: reminders,
          appVersion: FakeAppVersion(),
          identity: identity,
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
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await settings.saveRemindersEnabled(enabled: true);
      await open(tester);

      await tapRow(tester, SettingsScreen.youAreRow);
      await tester.tap(find.text('Sisi').last);
      await tester.pumpAndSettle();

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

  group('signing in (#76)', () {
    testWidgets('it will not start before the app knows who you are', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await tapRow(tester, SettingsScreen.signInRow);

      expect(identity.signInCalls, 0);
      expect(
        find.textContaining('Say which one you are first'),
        findsOneWidget,
      );
    });

    testWidgets('signing in ties the account to that person', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      identity.next = const SignedIn(
        uid: 'uid-mama',
        displayName: 'Mama Mashibini',
      );
      await open(tester);
      await tapRow(tester, SettingsScreen.signInRow);

      final Family stored = (await family.load())!;
      expect(stored.membersById[mama.id]!.uid, 'uid-mama');
      expect(stored.memberUids, <String>[
        'uid-mama',
      ], reason: 'this is what lets anything sync at all');
    });

    testWidgets('and the row then says who, as whom', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      identity.next = const SignedIn(
        uid: 'uid-mama',
        displayName: 'Mama Mashibini',
      );
      await open(tester);
      await tapRow(tester, SettingsScreen.signInRow);
      await reveal(tester, SettingsScreen.signInRow);

      expect(find.textContaining('as Mama'), findsOneWidget);
    });

    testWidgets('changing your mind in the sheet changes nothing', (
      WidgetTester tester,
    ) async {
      // Dismissing the sheet is an ordinary answer, not a failure.
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      identity.next = null;
      await open(tester);
      await tapRow(tester, SettingsScreen.signInRow);

      expect(identity.signInCalls, 1);
      expect((await family.load())!.memberUids, isEmpty);
    });

    testWidgets('an account already on somebody else says whose', (
      WidgetTester tester,
    ) async {
      await family.save(
        FamilyEditor.linkUid(
          familyOfFour(),
          memberId: tata.id,
          uid: 'uid-shared',
        ),
      );
      await settings.saveYouAre(mama.id);
      identity.next = const SignedIn(uid: 'uid-shared');
      await open(tester);
      await tapRow(tester, SettingsScreen.signInRow);

      expect(find.textContaining('Tata'), findsWidgets);
      expect((await family.load())!.membersById[mama.id]!.uid, isNull);
    });

    testWidgets('a sign-in that fails is said out loud', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      identity.throws = StateError('no network');
      await open(tester);
      await tapRow(tester, SettingsScreen.signInRow);

      expect(find.textContaining('did not work'), findsOneWidget);
    });

    testWidgets('signing out keeps you in the rota and does not unlink', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      identity.next = const SignedIn(uid: 'uid-mama');
      await open(tester);
      await tapRow(tester, SettingsScreen.signInRow);

      await tapRow(tester, SettingsScreen.signInRow);
      await tester.tap(find.byKey(SettingsScreen.confirmSignOut));
      await tester.pumpAndSettle();

      expect(identity.signOutCalls, 1);
      expect(
        (await family.load())!.membersById[mama.id]!.uid,
        'uid-mama',
        reason: 'signing out is not unlinking',
      );
    });

    testWidgets('and it says so before you agree to it', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      identity.next = const SignedIn(uid: 'uid-mama');
      await open(tester);
      await tapRow(tester, SettingsScreen.signInRow);
      await tapRow(tester, SettingsScreen.signInRow);

      expect(
        find.textContaining('Your name stays in the rota'),
        findsOneWidget,
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

    testWidgets('it is a control now, which took two days to earn', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await reveal(tester, SettingsScreen.turnoverRow);

      final ListTile row = tester.widget<ListTile>(
        find.byKey(SettingsScreen.turnoverRow),
      );
      expect(row.onTap, isNotNull);
      expect(row.enabled, isTrue);
    });
  });

  group('moving the day the week turns over', () {
    Future<void> choose(WidgetTester tester, String day) async {
      await tapRow(tester, SettingsScreen.turnoverRow);
      await tester.tap(find.text(day));
      await tester.pumpAndSettle();
    }

    testWidgets('it offers all seven days, with today\'s ticked', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await tapRow(tester, SettingsScreen.turnoverRow);

      for (final String day in <String>[
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ]) {
        expect(find.text(day), findsOneWidget, reason: '$day is not offered');
      }
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('it says the date, the short week and who gets it', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await choose(tester, 'Wednesday');

      expect(find.text('Hand over on Wednesday?'), findsOneWidget);
      expect(find.textContaining('28 October 2026'), findsOneWidget);
      expect(find.textContaining('Sisi has the week before'), findsOneWidget);
      expect(find.textContaining('3 days instead of seven'), findsOneWidget);
      expect(
        find.textContaining('Mama takes the first full week'),
        findsOneWidget,
      );
    });

    testWidgets('leaving it changes nothing', (WidgetTester tester) async {
      await family.save(familyOfFour());
      final Family before = (await family.load())!;
      await open(tester);
      await choose(tester, 'Wednesday');
      await tester.tap(find.text('Leave it'));
      await tester.pumpAndSettle();

      final Family after = (await family.load())!;
      expect(after.cycles, hasLength(before.cycles.length));
      expect(after.turnoverWeekday, DateTime.sunday);
    });

    testWidgets('changing it writes the family the dialog described', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await choose(tester, 'Wednesday');
      await tester.tap(find.byKey(SettingsScreen.confirmTurnover));
      await tester.pumpAndSettle();

      final Family after = (await family.load())!;
      expect(after.turnoverWeekday, DateTime.wednesday);
      expect(after.cycles, hasLength(2));
      expect(after.cycles.last.effectiveFrom, CalendarDate(2026, 10, 28));

      final RotaEngine engine = RotaEngine.forFamily(after);
      expect(engine.turnOn(anchor)!.leader, jabulile);
      expect(engine.turnOn(CalendarDate(2026, 10, 25))!.leader, sisi);
      expect(
        engine.turnOn(CalendarDate(2026, 10, 25))!.weekEnd,
        CalendarDate(2026, 10, 27),
      );
      expect(engine.turnOn(CalendarDate(2026, 10, 28))!.leader, mama);
    });

    testWidgets('choosing the day it already is does nothing', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await choose(tester, 'Sunday');

      // No confirmation, because there is nothing to confirm.
      expect(find.byKey(SettingsScreen.confirmTurnover), findsNothing);
      expect((await family.load())!.cycles, hasLength(1));
    });

    testWidgets('while a change is pending, the row says both days', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await choose(tester, 'Wednesday');
      await tester.tap(find.byKey(SettingsScreen.confirmTurnover));
      await tester.pumpAndSettle();
      await reveal(tester, SettingsScreen.turnoverRow);

      expect(find.textContaining('Sunday this week'), findsOneWidget);
      expect(find.textContaining('Wednesday from'), findsOneWidget);
    });

    testWidgets('and reminders move with it', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(sisi.id);
      await settings.saveRemindersEnabled(enabled: true);
      await open(tester);

      final Set<int> before = await reminders.pending();
      await choose(tester, 'Wednesday');
      await tester.tap(find.byKey(SettingsScreen.confirmTurnover));
      await tester.pumpAndSettle();

      expect(await reminders.pending(), isNot(before));
    });
  });

  group('who takes a week', () {
    testWidgets('the row lists them, so the screen answers before it opens', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await reveal(tester, SettingsScreen.membersRow);

      expect(find.text('Jabulile, Sisi, Mama, Tata'), findsOneWidget);
    });

    testWidgets('it opens the screen that #74 was asking for', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await tapRow(tester, SettingsScreen.membersRow);

      expect(find.text('Who takes a week'), findsWidgets);
      expect(find.byKey(FamilyMembersScreen.addRow), findsOneWidget);
    });

    testWidgets('and says to set the rota up first when there is none', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await reveal(tester, SettingsScreen.membersRow);

      final ListTile row = tester.widget<ListTile>(
        find.byKey(SettingsScreen.membersRow),
      );
      expect(row.onTap, isNull);
    });
  });

  group('keeping a copy of the journal', () {
    testWidgets('hands the whole journal to the share sheet', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await journal.write(
        date: anchor,
        text: 'Thanked God for the rain.',
        now: DateTime(2026, 10, 18, 21),
      );
      await journal.write(
        date: anchor.addDays(1),
        text: 'Prayed for Gogo.',
        now: DateTime(2026, 10, 19, 21),
      );
      await open(tester);

      await tapRow(tester, SettingsScreen.exportRow);

      expect(sharing.shares, 1);
      expect(sharing.sharedText, contains('Thanked God for the rain.'));
      expect(sharing.sharedText, contains('Prayed for Gogo.'));
      expect(sharing.sharedSubject, contains('My prayer journal'));
      expect(
        sharing.sharedSubject,
        contains('Sunday, 18 October 2026'),
        reason: 'the subject reads the way the document does',
      );
    });

    testWidgets('dates it the way the rest of the app does', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await journal.write(
        date: anchor,
        text: 'A line.',
        now: DateTime(2026, 10, 18, 21),
      );
      await open(tester);

      await tapRow(tester, SettingsScreen.exportRow);

      expect(sharing.sharedText, contains('Sunday, 18 October 2026'));
    });

    testWidgets('an empty journal still produces something', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tapRow(tester, SettingsScreen.exportRow);

      expect(sharing.shares, 1);
      expect(sharing.sharedText, contains('Nothing written yet.'));
    });

    testWidgets('a share sheet that will not open is said out loud', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      sharing.throws = Exception('no share sheet here');
      await open(tester);

      await tapRow(tester, SettingsScreen.exportRow);

      expect(find.textContaining('could not share it'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);
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

      await tester.scrollUntilVisible(
        find.text('Reinstalling loses your journal'),
        160,
      );
      await tester.pumpAndSettle();
      expect(find.text('Reinstalling loses your journal'), findsOneWidget);
    });
  });
}
