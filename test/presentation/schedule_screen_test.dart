import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/calendar_date.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/presentation/screens/schedule_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

void main() {
  late LocalFamilyRepository family;
  late LocalDeviceSettingsRepository settings;

  setUp(() {
    final FakeKeyValueStore store = FakeKeyValueStore();
    family = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
  });

  tearDown(() async {
    await family.dispose();
    await settings.dispose();
  });

  Future<void> open(WidgetTester tester, {CalendarDate? today}) async {
    // Tall enough for all eight rows. R1.5 is about seeing eight turns, and
    // the default 800x600 test window cuts the last one off — which would
    // make the counts below quietly measure the viewport instead of the rota.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: ScheduleScreen(
          familyRepository: family,
          settings: settings,
          ids: FakeIdGenerator(),
          today: () => today ?? anchor,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('seeing the cycle ahead (R1.5)', () {
    testWidgets('shows eight turns with their leaders', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      // Four people over eight weeks: each name appears twice.
      for (final String name in <String>['Jabulile', 'Sisi', 'Mama', 'Tata']) {
        expect(find.text(name), findsNWidgets(2));
      }
    });

    testWidgets('each turn carries its date', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await open(tester);

      // The week in progress is labelled rather than dated — "This week" is
      // what somebody standing in it wants to read.
      expect(find.text('This week'), findsOneWidget);
      expect(find.textContaining('25 October 2026'), findsOneWidget);
      expect(find.textContaining('1 November 2026'), findsOneWidget);
    });

    testWidgets('says so plainly when the rota has not started', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester, today: anchor.subtractDays(28));

      expect(find.textContaining('has not started yet'), findsOneWidget);
    });
  });

  group('skipping a turn (R1.4)', () {
    testWidgets('the week passes to the next person', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(
        find.byKey(ScheduleScreen.skipButton(anchor.addDays(7))),
      );
      await tester.pumpAndSettle();

      final Family? stored = await family.load();
      expect(stored!.skips.single.memberId, sisi.id);
      expect(stored.skips.single.weekStart, anchor.addDays(7));
    });

    testWidgets('the row stays, saying whose turn was passed over', (
      WidgetTester tester,
    ) async {
      // Without this the skip is invisible the moment it is made, and there
      // is nothing left to undo.
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(
        find.byKey(ScheduleScreen.skipButton(anchor.addDays(7))),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Sisi's turn was passed over"),
        findsOneWidget,
      );
      expect(
        find.byKey(ScheduleScreen.undoButton(anchor.addDays(7))),
        findsOneWidget,
      );
    });

    testWidgets('the week in progress offers no skip', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(find.byKey(ScheduleScreen.skipButton(anchor)), findsNothing);
    });

    testWidgets('the list reflows so later weeks move up', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(
        find.byKey(ScheduleScreen.skipButton(anchor.addDays(7))),
      );
      await tester.pumpAndSettle();

      // Everyone after the skipped week moves up one, so the eight weeks
      // read J, M, T, J, S, M, T, J instead of J, S, M, T, J, S, M, T.
      // Sisi loses one of her two turns and does not get it back later —
      // the whole point of R1.4's "forgiveness, not debt", visible here as
      // a count.
      expect(find.text('Jabulile'), findsNWidgets(3));
      expect(find.text('Mama'), findsNWidgets(2));
      expect(find.text('Tata'), findsNWidgets(2));
      expect(find.text('Sisi'), findsOneWidget);
    });
  });

  group('taking it back', () {
    testWidgets('undo restores the original leader', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(
        find.byKey(ScheduleScreen.skipButton(anchor.addDays(7))),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ScheduleScreen.undoButton(anchor.addDays(7))),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('passed over'), findsNothing);
      expect(
        find.byKey(ScheduleScreen.skipButton(anchor.addDays(7))),
        findsOneWidget,
      );
      expect((await family.load())!.skips.single.withdrawn, isTrue);
    });

    testWidgets('a week can be skipped again after being restored', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      for (int i = 0; i < 2; i++) {
        await tester.tap(
          find.byKey(ScheduleScreen.skipButton(anchor.addDays(7))),
        );
        await tester.pumpAndSettle();
        if (i == 0) {
          await tester.tap(
            find.byKey(ScheduleScreen.undoButton(anchor.addDays(7))),
          );
          await tester.pumpAndSettle();
        }
      }

      final Family stored = (await family.load())!;
      expect(stored.skips, hasLength(2));
      expect(
        find.textContaining("Sisi's turn was passed over"),
        findsOneWidget,
      );
    });
  });

  group('the screen stays usable (found on the simulator)', () {
    testWidgets('an edit re-enables the controls even if nothing is '
        'listening for announcements', (WidgetTester tester) async {
      // On a device with no screen reader running, the accessibility channel
      // has no listener and the send never completes. Awaiting it left every
      // button here disabled forever. The default test binding answers the
      // channel immediately, which is why the other tests in this file pass
      // either way — so this one makes the channel behave like the device.
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        SystemChannels.accessibility.name,
        (ByteData? message) => Completer<ByteData?>().future,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          SystemChannels.accessibility.name,
          null,
        ),
      );

      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(
        find.byKey(ScheduleScreen.skipButton(anchor.addDays(7))),
      );
      await tester.pumpAndSettle();

      final Finder undo = find.byKey(
        ScheduleScreen.undoButton(anchor.addDays(7)),
      );
      expect(
        tester.widget<TextButton>(undo).onPressed,
        isNotNull,
        reason: 'the screen must not lock itself waiting to be heard',
      );

      // And it really still works.
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect((await family.load())!.skips.single.withdrawn, isTrue);
    });
  });

  group('whose week it is', () {
    testWidgets('this phone is told "You" rather than its own name', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      await open(tester);

      expect(find.text('You'), findsNWidgets(2));
      expect(find.text('Mama'), findsNothing);
    });
  });
}
