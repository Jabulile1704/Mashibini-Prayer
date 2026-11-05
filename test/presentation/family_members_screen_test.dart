import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';
import 'package:mashibini_prayer/src/presentation/screens/family_members_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_reminders.dart';
import '../support/family_fixtures.dart';

/// #74 — the gap this screen closes.
///
/// `FamilyEditor` could add and remove people from Day 7 and nothing called
/// it for fourteen days. Somebody joined or left and the app's only answer
/// was "start the rota again", which throws away the order, the turnover day
/// and every skip the family had recorded.
///
/// These tests are mostly about one thing: **the screen must not invent
/// rules, and must not hide the ones it has.** The domain defers changes to
/// the next turnover and refuses to go below two people; a screen that
/// re-implemented either would be a second opinion, and a screen that stayed
/// quiet about them would be a surprise.
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
        home: FamilyMembersScreen(
          familyRepository: family,
          settings: settings,
          reminders: reminders,
          ids: FakeIdGenerator(),
          today: () => anchor.addDays(2), // a Tuesday, mid-week
          now: () => DateTime(2026, 10, 20, 9),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addSomebody(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(FamilyMembersScreen.addRow));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(FamilyMembersScreen.nameField), name);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FamilyMembersScreen.confirmAdd));
    await tester.pumpAndSettle();
  }

  group('who is in the rota', () {
    testWidgets('everybody, in the order they take their turns', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      for (final Member member in <Member>[jabulile, sisi, mama, tata]) {
        expect(
          find.byKey(FamilyMembersScreen.rowFor(member.id)),
          findsOneWidget,
        );
      }
    });

    testWidgets('each one says when their next turn is', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      // Today is inside Jabulile's week. The list is the roster from next
      // Sunday, but the turns under each name are read off the engine from
      // today, so the person currently leading still says so.
      expect(find.text('Leading this week'), findsOneWidget);
      expect(
        find.textContaining('Next: Sun'),
        findsWidgets,
        reason: 'everybody else has a date',
      );
    });

    testWidgets('it says when a change would start, before anything is '
        'changed', (WidgetTester tester) async {
      // The whole reason this screen can be trusted. Every edit here lands
      // at the next turnover, not now, and a screen that did not say so
      // would look broken to somebody who added a name and saw this week
      // unchanged.
      await family.save(familyOfFour());
      await open(tester);

      expect(find.textContaining('25 October 2026'), findsOneWidget);
    });

    testWidgets('and says so before a rota exists, rather than nothing', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.text('Set the rota up first.'), findsOneWidget);
    });
  });

  group('adding somebody', () {
    testWidgets('they appear, and they take their turn last', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await addSomebody(tester, 'Cousin');

      final Family after = (await family.load())!;
      final List<Member> order = FamilyEditor.activeMembers(
        after,
        anchor.addDays(9), // inside the new epoch
      );
      expect(order.last.displayName, 'Cousin');
      expect(order, hasLength(5));
    });

    testWidgets('this week is not touched', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await open(tester);
      await addSomebody(tester, 'Cousin');

      final Family after = (await family.load())!;
      expect(
        RotaEngine.forFamily(after).turnOn(anchor.addDays(2))!.leader,
        jabulile,
      );
    });

    testWidgets('the name is trimmed, so a stray space is not a name', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await addSomebody(tester, '  Cousin  ');

      final Family after = (await family.load())!;
      expect(
        after.members.map((Member m) => m.displayName),
        contains('Cousin'),
      );
    });

    testWidgets('Add does nothing until there is a name to add', (
      WidgetTester tester,
    ) async {
      // Disabled rather than tappable-and-silent. A button that accepts a
      // tap and does nothing is a button somebody taps again harder.
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(FamilyMembersScreen.addRow));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextButton>(find.byKey(FamilyMembersScreen.confirmAdd))
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byKey(FamilyMembersScreen.nameField), '   ');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.byKey(FamilyMembersScreen.confirmAdd))
            .onPressed,
        isNull,
        reason: 'whitespace is not a name',
      );
    });

    testWidgets('the dialog names the day they join', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(FamilyMembersScreen.addRow));
      await tester.pumpAndSettle();

      expect(find.textContaining('25 October 2026'), findsWidgets);
      expect(
        find.textContaining('everybody already in the rota goes first'),
        findsOneWidget,
      );
    });
  });

  group('removing somebody', () {
    testWidgets('it asks first, and says what will happen', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(FamilyMembersScreen.removeFor(mama.id)));
      await tester.pumpAndSettle();

      expect(find.text('Take Mama out of the rota?'), findsOneWidget);
      // The date, who leads instead, and the promise about past weeks.
      expect(find.textContaining('25 October 2026'), findsWidgets);
      expect(find.textContaining('Sisi leads that week'), findsOneWidget);
      expect(find.textContaining('already led keep their name'), findsWidgets);
    });

    testWidgets('declining changes nothing at all', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      final Family before = (await family.load())!;
      await open(tester);

      await tester.tap(find.byKey(FamilyMembersScreen.removeFor(mama.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep them'));
      await tester.pumpAndSettle();

      final Family after = (await family.load())!;
      expect(after.cycles, hasLength(before.cycles.length));
      expect(find.byKey(FamilyMembersScreen.rowFor(mama.id)), findsOneWidget);
    });

    testWidgets('confirming takes them out from the next turnover', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(FamilyMembersScreen.removeFor(mama.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamilyMembersScreen.confirmRemove));
      await tester.pumpAndSettle();

      final Family after = (await family.load())!;
      expect(
        FamilyEditor.activeMembers(
          after,
          anchor.addDays(9),
        ).map((Member m) => m.displayName),
        isNot(contains('Mama')),
      );
      // Still in `members`, because a week she led in October keeps her name
      // (R2.3). The screen must not have "cleaned up" after the domain.
      expect(after.members.map((Member m) => m.displayName), contains('Mama'));
      expect(
        RotaEngine.forFamily(after).turnOn(anchor.addDays(2))!.leader,
        jabulile,
        reason: 'this week is not changed by a removal',
      );
    });

    testWidgets('the row goes once it is done', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(FamilyMembersScreen.removeFor(tata.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamilyMembersScreen.confirmRemove));
      await tester.pumpAndSettle();

      expect(find.byKey(FamilyMembersScreen.rowFor(tata.id)), findsNothing);
    });
  });

  group('the floor of two', () {
    /// A rota of exactly two, which is the smallest the domain allows.
    Future<void> saveTwo() => family.save(
      Family(
        id: 'f1',
        name: 'Mashibini',
        members: const <Member>[jabulile, sisi],
        cycles: familyOfFour().cycles,
      ),
    );

    testWidgets('neither of two can be taken out, and the row says why', (
      WidgetTester tester,
    ) async {
      // The domain throws on this. A screen that let somebody tap and then
      // showed them the exception would be delivering the same information
      // rudely, so the reason is on the screen and the buttons are off.
      await saveTwo();
      await open(tester);

      expect(find.textContaining('needs at least two people'), findsOneWidget);
      for (final Member member in <Member>[jabulile, sisi]) {
        expect(
          tester
              .widget<IconButton>(
                find.byKey(FamilyMembersScreen.removeFor(member.id)),
              )
              .onPressed,
          isNull,
        );
      }
    });

    testWidgets('adding a third makes removal possible again', (
      WidgetTester tester,
    ) async {
      await saveTwo();
      await open(tester);
      await addSomebody(tester, 'Cousin');

      expect(find.textContaining('needs at least two people'), findsNothing);
    });
  });

  group('reminders follow the rota', () {
    testWidgets('adding somebody re-plans what this phone holds', (
      WidgetTester tester,
    ) async {
      // Adding a person pushes everybody else's turns later. A phone that
      // kept its old plan would ring on an evening that is no longer the
      // night before anybody's week — the silent kind of wrong, which is
      // why every write on this screen reschedules.
      await family.save(familyOfFour());
      await settings.saveYouAre(tata.id);
      await settings.saveRemindersEnabled(enabled: true);
      await open(tester);

      final Set<int> before = await reminders.pending();
      await addSomebody(tester, 'Cousin');
      final Set<int> after = await reminders.pending();

      expect(after, isNotEmpty);
      expect(
        after,
        isNot(before),
        reason: 'Tata now leads later, so the dates must have moved',
      );
    });

    testWidgets('nothing is scheduled while reminders are switched off', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(tata.id);
      await open(tester);
      await addSomebody(tester, 'Cousin');

      expect(await reminders.pending(), isEmpty);
    });
  });
}
