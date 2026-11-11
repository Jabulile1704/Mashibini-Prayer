import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/rota/rota_engine.dart';
import 'package:mashibini_prayer/src/presentation/screens/setup_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

void main() {
  late LocalFamilyRepository repository;
  late LocalDeviceSettingsRepository settings;

  setUp(() {
    final FakeKeyValueStore store = FakeKeyValueStore();
    repository = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
  });

  tearDown(() async {
    await repository.dispose();
    await settings.dispose();
  });

  Future<void> open(WidgetTester tester, {CalendarDate? on}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: SetupScreen(
          familyRepository: repository,
          settingsRepository: settings,
          ids: FakeIdGenerator(),
          today: () => on ?? anchor,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> typeName(WidgetTester tester, int row, String name) async {
    await tester.enterText(find.byType(TextFormField).at(row), name);
    await tester.pumpAndSettle();
  }

  /// Picks [value] in the dropdown identified by [field].
  Future<void> choose(
    WidgetTester tester, {
    required Key field,
    required String value,
  }) async {
    await tester.scrollUntilVisible(
      find.byKey(field),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(field));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(field));
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  /// The button sits below the fold, and a ListView does not build what it
  /// has not scrolled to — so this scrolls first, the way a person would.
  Future<void> tapStart(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(SetupScreen.startButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(SetupScreen.startButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SetupScreen.startButton));
    await tester.pumpAndSettle();
  }

  group('what it asks for', () {
    testWidgets('two questions now, and never the word anchor', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('Whose week is it?'), findsOneWidget);
      expect(find.text('Your week turns over on'), findsOneWidget);
      expect(find.text('Whose week is it at the moment?'), findsNothing);
      expect(find.textContaining('anchor'), findsNothing);
      expect(find.textContaining('Anchor'), findsNothing);
    });

    testWidgets('the list says which week each position covers', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.textContaining('FROM '), findsOneWidget);
    });

    testWidgets('it says the cycle comes back round', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await typeName(tester, 0, 'Jabulile');
      await typeName(tester, 1, 'Sisi');

      expect(find.textContaining('back to Jabulile'), findsOneWidget);
    });

    testWidgets('starts with two rows, since a rota needs two people', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('more rows can be added', (WidgetTester tester) async {
      await open(tester);

      await tester.tap(find.text('Add someone'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(3));
    });
  });

  group('refusing to make a broken rota', () {
    testWidgets('fewer than two people is explained, not silently ignored', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await typeName(tester, 0, 'Jabulile');

      await tapStart(tester);

      expect(find.text('A rota needs at least two people.'), findsOneWidget);
      expect(await repository.load(), isNull);
    });

    testWidgets('whose week it is cannot be left unanswered any more', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await typeName(tester, 0, 'Jabulile');
      await typeName(tester, 1, 'Sisi');

      await tapStart(tester);

      final Family saved = (await repository.load())!;
      expect(
        RotaEngine.forFamily(saved).turnOn(anchor)!.leader.displayName,
        'Jabulile',
      );
    });

    testWidgets('nothing is saved until the answers are complete', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tapStart(tester);

      expect(await repository.load(), isNull);
      expect(await settings.loadYouAre(), isNull);
    });
  });

  group('changing your mind', () {
    testWidgets('a person can be removed once there are more than two', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await typeName(tester, 0, 'Jabulile');
      await typeName(tester, 1, 'Sisi');
      await tester.tap(find.text('Add someone'));
      await tester.pumpAndSettle();
      await typeName(tester, 2, 'Mama');

      expect(find.byType(TextFormField), findsNWidgets(3));

      await tester.tap(find.byTooltip('Remove this person').last);
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('the last two rows cannot be removed', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.byTooltip('Remove person 1'), findsNothing);
      expect(find.byTooltip('Remove person 2'), findsNothing);
    });

    testWidgets('removing someone does not strand the rota', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await typeName(tester, 0, 'Jabulile');
      await typeName(tester, 1, 'Sisi');
      await tester.tap(find.text('Add someone'));
      await tester.pumpAndSettle();
      await typeName(tester, 2, 'Mama');

      await tester.tap(find.byTooltip('Remove this person').last);
      await tester.pumpAndSettle();
      await tapStart(tester);

      final Family saved = (await repository.load())!;
      expect(saved.members.map((Member m) => m.displayName), <String>[
        'Jabulile',
        'Sisi',
      ]);
    });
  });

  group('starting the rota (R2.1, R2.2)', () {
    Future<void> fillInTheMashibinis(WidgetTester tester) async {
      await typeName(tester, 0, 'Jabulile');
      await typeName(tester, 1, 'Sisi');
      await tester.tap(find.text('Add someone'));
      await tester.pumpAndSettle();
      await typeName(tester, 2, 'Mama');
      await tester.tap(find.text('Add someone'));
      await tester.pumpAndSettle();
      await typeName(tester, 3, 'Tata');
    }

    testWidgets('saves a family that already knows whose week it is', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await fillInTheMashibinis(tester);

      await tapStart(tester);

      final Family? saved = await repository.load();
      expect(saved, isNotNull);
      expect(saved!.members.map((Member m) => m.displayName), <String>[
        'Jabulile',
        'Sisi',
        'Mama',
        'Tata',
      ]);
      expect(saved.turnoverWeekday, DateTime.monday);

      final RotaEngine engine = RotaEngine.forFamily(saved);
      expect(engine.turnOn(anchor)!.leader.displayName, 'Jabulile');
      expect(engine.turnOn(anchor.addDays(7))!.leader.displayName, 'Sisi');
      expect(engine.turnOn(anchor.addDays(14))!.leader.displayName, 'Mama');
      expect(engine.turnOn(anchor.addDays(21))!.leader.displayName, 'Tata');
      expect(
        engine.turnOn(anchor.addDays(28))!.leader.displayName,
        'Jabulile',
        reason: 'and then it comes back round',
      );
    });

    testWidgets('the turnover day is what was chosen', (
      WidgetTester tester,
    ) async {
      // A Wednesday, so the chosen turnover is not the default.
      await open(tester, on: CalendarDate(2026, 10, 21));
      await fillInTheMashibinis(tester);
      await choose(
        tester,
        field: SetupScreen.turnoverDayField,
        value: 'Wednesday',
      );

      await tapStart(tester);

      final Family saved = (await repository.load())!;
      expect(saved.turnoverWeekday, DateTime.wednesday);
      expect(saved.cycles.single.effectiveFrom, CalendarDate(2026, 10, 21));
    });

    testWidgets('who you are is optional, and remembered when given', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await fillInTheMashibinis(tester);
      await choose(tester, field: SetupScreen.youAreField, value: 'Sisi');

      await tapStart(tester);

      final Family saved = (await repository.load())!;
      final String youAre = (await settings.loadYouAre())!;
      expect(
        saved.members.firstWhere((Member m) => m.id == youAre).displayName,
        'Sisi',
      );
    });

    testWidgets('skipping who you are saves nothing about you', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await fillInTheMashibinis(tester);

      await tapStart(tester);

      expect(await repository.load(), isNotNull);
      expect(await settings.loadYouAre(), isNull);
    });

    testWidgets('setting up mid-week carries on from the week in progress', (
      WidgetTester tester,
    ) async {
      await open(tester, on: anchor.addDays(3));
      await fillInTheMashibinis(tester);

      await tapStart(tester);

      final Family saved = (await repository.load())!;
      expect(saved.cycles.single.effectiveFrom, anchor.addDays(1));
      expect(
        RotaEngine.forFamily(saved)
            .turnOn(anchor.addDays(3))!
            .leader
            .displayName,
        'Jabulile',
        reason: 'the first in the list is leading the week in progress',
      );
    });

    testWidgets('dragging somebody to the top makes it their week', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await fillInTheMashibinis(tester);

      final Offset handle = tester.getCenter(
        find.byIcon(Icons.drag_handle).at(2),
      );
      final TestGesture drag = await tester.startGesture(handle);
      await tester.pump(const Duration(milliseconds: 200));
      for (int step = 0; step < 6; step++) {
        await drag.moveBy(const Offset(0, -40));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await drag.up();
      await tester.pumpAndSettle();

      await tapStart(tester);

      final RotaEngine engine = RotaEngine.forFamily(
        (await repository.load())!,
      );
      expect(engine.turnOn(anchor)!.leader.displayName, 'Mama');
      expect(engine.turnOn(anchor.addDays(7))!.leader.displayName, 'Jabulile');
    });
  });
}
