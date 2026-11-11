import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/entities/saying.dart';
import 'package:mashibini_prayer/src/presentation/screens/this_week_screen.dart';
import 'package:mashibini_prayer/src/presentation/widgets/saying_card.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

void main() {
  late LocalFamilyRepository repository;
  late LocalDeviceSettingsRepository settings;
  late LocalJournalRepository journal;

  setUp(() {
    final FakeKeyValueStore store = FakeKeyValueStore();
    repository = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    journal = LocalJournalRepository(store: store, ids: FakeIdGenerator());
  });

  tearDown(() async {
    await repository.dispose();
    await settings.dispose();
    await journal.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    required CalendarDate on,
    String? youAre,
    bool settle = true,
  }) async {
    if (youAre != null) {
      await settings.saveYouAre(youAre);
    }
    await tester.pumpWidget(
      MaterialApp(
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
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

      expect(find.text('Whose week is it?'), findsOneWidget);
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

  group("today's saying (R3.1, R3.2)", () {
    /// The saying the screen actually chose, read off the card rather than
    /// guessed from the date. Which one lands on `anchor` is arithmetic over
    /// a file that changes whenever a proverb is added, and a test that
    /// hard-codes the answer breaks on every such addition while proving
    /// nothing about the screen.
    Saying shown(WidgetTester tester) =>
        tester.widget<SayingCard>(find.byType(SayingCard)).saying;

    testWidgets('a saying appears alongside the rota', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());
      await show(tester, on: anchor);

      final Saying saying = shown(tester);

      expect(find.text(saying.text), findsOneWidget);
      expect(find.text(saying.language), findsOneWidget);
    });

    testWidgets('a saying in its own language leads with it', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());
      await show(tester, on: anchor);

      final String? original = shown(tester).original;
      if (original == null) {
        return;
      }

      final Text text = tester.widget<Text>(find.text(original));
      expect(text.style!.fontStyle, FontStyle.italic);
    });

    testWidgets('the saying is quieter than the leader', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());
      await show(tester, on: anchor);

      final double leader = tester
          .widget<Text>(find.text('Jabulile'))
          .style!
          .fontSize!;
      final Text language = tester.widget<Text>(
        find.text(shown(tester).language),
      );
      expect(language.style!.fontSize, lessThan(leader));
    });

    testWidgets('the same date gives the same saying on a rebuild', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());
      await show(tester, on: anchor);
      final Saying first = shown(tester);

      await show(tester, on: anchor);
      expect(shown(tester), first);
    });

    testWidgets('a different date gives a different saying', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());
      await show(tester, on: anchor);
      final Saying today = shown(tester);

      await show(tester, on: anchor.addDays(1));
      expect(shown(tester), isNot(today));
    });

    testWidgets('the empty state shows no saying', (WidgetTester tester) async {
      await show(tester, on: anchor);

      expect(find.text('No rota yet'), findsOneWidget);
      expect(find.byType(SayingCard), findsNothing);
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
  group('which build this is', () {
    testWidgets('the version is not here any more — it moved to Settings', (
      WidgetTester tester,
    ) async {
      await repository.save(familyOfFour());

      await show(tester, on: anchor);

      expect(find.textContaining('Version'), findsNothing);
    });
  });
}
