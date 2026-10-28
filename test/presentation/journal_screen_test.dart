import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/presentation/screens/journal_screen.dart';
import 'package:mashibini_prayer/src/presentation/screens/write_entry_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';

void main() {
  late LocalJournalRepository journal;

  final CalendarDate today = CalendarDate(2026, 10, 28);
  final DateTime noon = DateTime.utc(2026, 10, 28, 12);

  setUp(() {
    journal = LocalJournalRepository(
      store: FakeKeyValueStore(),
      ids: FakeIdGenerator(),
    );
  });

  tearDown(() async => journal.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: JournalScreen(journal: journal, today: () => today),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('nothing written yet', () {
    testWidgets('says so, and says where entries live', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('Nothing written yet'), findsOneWidget);
      expect(find.textContaining('stays on this phone'), findsOneWidget);
    });

    testWidgets('the promise is scoped to what is true today', (
      WidgetTester tester,
    ) async {
      await open(tester);

      // Nothing signs in yet, so "private to you" would be a promise this
      // build cannot keep. The phone is the boundary, and the words say so.
      expect(find.textContaining('not sent anywhere'), findsOneWidget);
      expect(find.textContaining('private to you'), findsNothing);
    });
  });

  group('writing an entry (R4.1)', () {
    testWidgets('what is typed is saved and shown', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(WriteEntryScreen.textField),
        'For Mama, travelling on Tuesday',
      );
      await tester.tap(find.byKey(WriteEntryScreen.saveButton));
      await tester.pumpAndSettle();

      expect(find.text('For Mama, travelling on Tuesday'), findsOneWidget);
      expect(find.text('Nothing written yet'), findsNothing);
      expect(
        (await journal.forDate(today))!.text,
        'For Mama, travelling on Tuesday',
      );
    });

    testWidgets('an existing entry opens with its text, and edits in place', (
      WidgetTester tester,
    ) async {
      await journal.write(date: today, text: 'First thoughts', now: noon);
      await open(tester);

      await tester.tap(find.text('First thoughts'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(WriteEntryScreen.textField))
            .controller!
            .text,
        'First thoughts',
      );

      await tester.enterText(
        find.byKey(WriteEntryScreen.textField),
        'Second thoughts',
      );
      await tester.tap(find.byKey(WriteEntryScreen.saveButton));
      await tester.pumpAndSettle();

      expect(find.text('Second thoughts'), findsOneWidget);
      expect(find.text('First thoughts'), findsNothing);
      expect(await journal.all(), hasLength(1));
    });

    testWidgets('clearing the box removes the entry', (
      WidgetTester tester,
    ) async {
      await journal.write(date: today, text: 'To be removed', now: noon);
      await open(tester);

      await tester.tap(find.text('To be removed'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(WriteEntryScreen.textField), '');
      await tester.tap(find.byKey(WriteEntryScreen.saveButton));
      await tester.pumpAndSettle();

      expect(find.text('Nothing written yet'), findsOneWidget);
      expect(await journal.all(), isEmpty);
    });

    testWidgets('the editor shows the date it is writing against', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.textContaining('28 October 2026'), findsOneWidget);
    });
  });

  group('looking back (R4.3)', () {
    testWidgets('entries are newest first', (WidgetTester tester) async {
      await journal.write(date: today, text: 'Today', now: noon);
      await journal.write(
        date: today.subtractDays(1),
        text: 'Yesterday',
        now: noon,
      );
      await open(tester);

      final Offset todayAt = tester.getTopLeft(find.text('Today'));
      final Offset yesterdayAt = tester.getTopLeft(find.text('Yesterday'));
      expect(todayAt.dy, lessThan(yesterdayAt.dy));
    });

    testWidgets('they are grouped under a month heading', (
      WidgetTester tester,
    ) async {
      await journal.write(date: today, text: 'In October', now: noon);
      await journal.write(
        date: CalendarDate(2026, 9, 20),
        text: 'In September',
        now: noon,
      );
      await open(tester);

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('one month gives one heading, not one per entry', (
      WidgetTester tester,
    ) async {
      for (int i = 0; i < 4; i++) {
        await journal.write(
          date: today.subtractDays(i),
          text: 'Entry $i',
          now: noon,
        );
      }
      await open(tester);

      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('a long entry is truncated rather than filling the screen', (
      WidgetTester tester,
    ) async {
      await journal.write(
        date: today,
        text: List<String>.filled(80, 'words and more words').join(' '),
        now: noon,
      );
      await open(tester);

      expect(tester.takeException(), isNull);
    });
  });
}
