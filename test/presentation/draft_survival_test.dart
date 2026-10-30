import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/journal_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/journal_entry.dart';
import 'package:mashibini_prayer/src/presentation/screens/write_entry_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

/// N7: the app's state survives being killed by the OS mid-session.
///
/// Everything else in this app already survived that, because everything
/// else is written the moment it changes. A half-written journal entry was
/// the exception — it lived in a TextEditingController and nowhere else —
/// and it is the one thing nobody would forgive losing.
///
/// A kill is simulated the only honest way a widget test can: throw the
/// whole widget tree away and build a new screen against the same store,
/// which is exactly what a relaunch does.
void main() {
  late FakeKeyValueStore store;
  late LocalJournalRepository journal;

  final DateTime now = DateTime(2026, 10, 18, 9);

  setUp(() {
    store = FakeKeyValueStore();
    journal = LocalJournalRepository(store: store, ids: FakeIdGenerator());
  });

  tearDown(() async => journal.dispose());

  Future<void> open(WidgetTester tester, {JournalEntry? existing}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: WriteEntryScreen(
          journal: journal,
          date: anchor,
          existing: existing,
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Types, waits past the debounce, then discards the tree.
  Future<void> typeThenCrash(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(WriteEntryScreen.textField), text);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  group('a half-written entry survives (N7)', () {
    testWidgets('text typed and never saved comes back', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await typeThenCrash(tester, 'Lord, thank you for');

      await open(tester);

      expect(find.text('Lord, thank you for'), findsOneWidget);
    });

    testWidgets('it is a draft, not an entry', (WidgetTester tester) async {
      await open(tester);
      await typeThenCrash(tester, 'Half a thought');

      // Nothing should appear in the journal itself until Save is pressed.
      expect(await journal.all(), isEmpty);
    });

    testWidgets('an edit to an existing entry survives, without overwriting '
        'what was saved', (WidgetTester tester) async {
      await journal.write(date: anchor, text: 'The original', now: now);
      final JournalEntry saved = (await journal.forDate(anchor))!;

      await open(tester, existing: saved);
      await typeThenCrash(tester, 'The original, extended');

      expect(
        (await journal.forDate(anchor))!.text,
        'The original',
        reason: 'an unsaved edit must not become the saved entry',
      );

      await open(tester, existing: (await journal.forDate(anchor))!);
      expect(find.text('The original, extended'), findsOneWidget);
    });

    testWidgets('clearing the box and leaving abandons the draft', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await typeThenCrash(tester, 'Something');

      await open(tester);
      await typeThenCrash(tester, '   ');

      await open(tester);
      expect(find.text('Something'), findsNothing);
      expect(await journal.loadDraft(anchor), isNull);
    });
  });

  group('saving clears the draft', () {
    testWidgets('the same text is not restored over the saved entry', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.enterText(
        find.byKey(WriteEntryScreen.textField),
        'A finished thought',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(WriteEntryScreen.saveButton));
      await tester.pumpAndSettle();

      expect(await journal.loadDraft(anchor), isNull);
      expect((await journal.forDate(anchor))!.text, 'A finished thought');
    });

    testWidgets('deleting an entry by emptying it clears the draft too', (
      WidgetTester tester,
    ) async {
      await journal.write(date: anchor, text: 'To be removed', now: now);
      await journal.saveDraft(date: anchor, text: 'Leftover');

      await journal.write(date: anchor, text: '', now: now);

      expect(await journal.all(), isEmpty);
      expect(await journal.loadDraft(anchor), isNull);
    });
  });

  group('the draft is written without waiting to be told', () {
    testWidgets('going to the background writes whatever is held', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.enterText(
        find.byKey(WriteEntryScreen.textField),
        'Mid sentence',
      );
      // Deliberately *inside* the debounce window: nothing is stored yet.
      await tester.pump(const Duration(milliseconds: 100));
      expect(await journal.loadDraft(anchor), isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(await journal.loadDraft(anchor), 'Mid sentence');
    });
  });
}
