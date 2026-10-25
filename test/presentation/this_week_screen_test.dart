import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/presentation/screens/this_week_screen.dart';

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

  Future<void> show(
    WidgetTester tester, {
    required CalendarDate on,
    String? youAre,
  }) async {
    if (youAre != null) {
      await settings.saveYouAre(youAre);
    }
    await tester.pumpWidget(
      MaterialApp(
        // The same locale configuration as the real app, so these assertions
        // are about what the family actually sees rather than about en_US.
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: ThisWeekScreen(
          repository: repository,
          settings: settings,
          ids: FakeIdGenerator(),
          today: () => on,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('nothing set up yet', () {
    testWidgets('invites setup rather than showing an empty rota', (
      WidgetTester tester,
    ) async {
      await show(tester, on: anchor);

      expect(find.text('No rota yet'), findsOneWidget);
      expect(find.text('Set up the rota'), findsOneWidget);
    });

    testWidgets('does not claim anybody is leading', (
      WidgetTester tester,
    ) async {
      await show(tester, on: anchor);

      expect(find.text('This week'), findsNothing);
      for (final Member member in <Member>[jabulile, sisi, mama, tata]) {
        expect(find.text(member.displayName), findsNothing);
      }
    });
  });

  group('whose week it is (R1.1)', () {
    testWidgets('names the leader, prominently', (WidgetTester tester) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor);

      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Jabulile'), findsOneWidget);
    });

    testWidgets('the leader is the largest text on the screen', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());
      await show(tester, on: anchor);

      final double leaderSize = tester
          .widget<Text>(find.text('Jabulile'))
          .style!
          .fontSize!;
      final Iterable<Text> others = tester
          .widgetList<Text>(find.byType(Text))
          .where((Text t) => t.data != 'Jabulile' && t.style?.fontSize != null);

      for (final Text other in others) {
        expect(
          other.style!.fontSize,
          lessThanOrEqualTo(leaderSize),
          reason:
              '"${other.data}" is at least as large as the leader\'s name, '
              'which is the one thing this screen exists to say',
        );
      }
    });

    testWidgets('speaks in the second person when the leader is you', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor, youAre: jabulile.id);

      expect(find.text("It's your week"), findsOneWidget);
      expect(find.text('Jabulile'), findsNothing);
    });

    testWidgets('uses the name when the leader is somebody else', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor, youAre: tata.id);

      expect(find.text('Jabulile'), findsOneWidget);
      expect(find.text("It's your week"), findsNothing);
    });

    testWidgets('never guesses it is you when nobody has said who you are', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor);

      expect(find.text("It's your week"), findsNothing);
      expect(find.text('Jabulile'), findsOneWidget);
    });

    testWidgets('reads correctly to a screen reader', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());
      await show(tester, on: anchor);

      expect(
        find.bySemanticsLabel('Jabulile is leading family prayer this week'),
        findsOneWidget,
      );
    });
  });

  group('who is next, and when (R1.2)', () {
    testWidgets('names the next leader and the day they start', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor);

      expect(find.text('Sisi'), findsOneWidget);
      expect(find.textContaining('from Sunday'), findsOneWidget);
      expect(find.textContaining('25 October 2026'), findsOneWidget);
    });

    testWidgets('the handover lands on the turnover day itself', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      // The last day of Jabulile's week.
      await show(tester, on: anchor.addDays(6));
      expect(find.text('Jabulile'), findsOneWidget);

      // The turnover day: Sisi, from the start of the day.
      await show(tester, on: anchor.addDays(7));
      expect(find.text('Sisi'), findsOneWidget);
    });

    testWidgets('says "You" for your own upcoming turn', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor, youAre: sisi.id);

      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('the week shown ends the day before the next one starts', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor);

      expect(find.textContaining('until Saturday'), findsOneWidget);
      expect(find.textContaining('24 October 2026'), findsOneWidget);
    });
  });

  group('set up, but not started yet', () {
    testWidgets('says when it starts instead of naming nobody', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor.subtractDays(7));

      expect(find.text('The rota starts on'), findsOneWidget);
      expect(find.textContaining('18 October 2026'), findsOneWidget);
      expect(find.text('Jabulile'), findsNothing);
    });

    testWidgets('is not confused with having no rota at all', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor.subtractDays(1));

      expect(find.text('The rota starts on'), findsOneWidget);
      expect(find.text('No rota yet'), findsNothing);
    });
  });

  group('keeping up with changes', () {
    testWidgets('redraws when the family is saved while open', (
      WidgetTester tester,
    ) async {
      await show(tester, on: anchor);
      expect(find.text('No rota yet'), findsOneWidget);

      await repository.save(familyOfFour());
      await tester.pumpAndSettle();

      expect(find.text('Jabulile'), findsOneWidget);
      expect(find.text('No rota yet'), findsNothing);
    });

    testWidgets('a renamed member shows the new name', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());
      await show(tester, on: anchor);
      expect(find.text('Jabulile'), findsOneWidget);

      await repository.save(
        familyOfFour().copyWith(
          members: const <Member>[
            Member(id: 'm1', displayName: 'Bhuti'),
            sisi,
            mama,
            tata,
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bhuti'), findsOneWidget);
      expect(find.text('Jabulile'), findsNothing);
    });
  });

  group('getting to setup', () {
    testWidgets('the empty state opens the setup screen', (
      WidgetTester tester,
    ) async {
      await show(tester, on: anchor);

      await tester.tap(find.text('Set up the rota'));
      await tester.pumpAndSettle();

      expect(find.text('Who takes a week?'), findsOneWidget);
    });

    testWidgets('coming back from setup shows the rota that was made', (
      WidgetTester tester,
    ) async {
      await show(tester, on: anchor);
      await tester.tap(find.text('Set up the rota'));
      await tester.pumpAndSettle();

      // Save a family as the setup screen would, then leave it.
      await repository.save(familyOfFour());
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Jabulile'), findsOneWidget);
      expect(find.text('No rota yet'), findsNothing);
    });

    testWidgets('a name saved for this phone makes it speak to you', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());
      await show(tester, on: anchor);
      expect(find.text('Jabulile'), findsOneWidget);

      await settings.saveYouAre(jabulile.id);
      await tester.pumpAndSettle();

      expect(find.text("It's your week"), findsOneWidget);
    });
  });

  group('a rota whose data has drifted', () {
    testWidgets('a cycle naming nobody who exists does not crash the screen', (
      WidgetTester tester,
    ) async {
      await repository.save(
        Family(
          id: 'f1',
          name: 'Mashibini',
          turnoverWeekday: DateTime.sunday,
          members: const <Member>[jabulile],
          cycles: <Cycle>[
            Cycle(
              id: 'c1',
              effectiveFrom: anchor,
              order: const <String>['ghost'],
            ),
          ],
        ),
      );

      await show(tester, on: anchor);

      expect(tester.takeException(), isNull);
      expect(find.text('The rota starts on'), findsOneWidget);
    });
  });
}
