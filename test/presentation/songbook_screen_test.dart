import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/song.dart';
import 'package:mashibini_prayer/src/domain/rota/family_editor.dart';
import 'package:mashibini_prayer/src/presentation/screens/songbook_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

/// The songbook (#110).
///
/// The thing this screen has to get right is not the list — it is saying
/// **everyone sees this**. It sits two tabs from a journal that is private
/// by requirement (R4.2), and somebody who has learned that about this app
/// will assume it here unless told otherwise.
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

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: SongbookScreen(
          familyRepository: family,
          settings: settings,
          ids: FakeIdGenerator(),
          today: () => anchor,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addSong(
    WidgetTester tester, {
    required String title,
    String? performer,
  }) async {
    await tester.tap(find.byKey(SongbookScreen.addSong));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(SongbookScreen.titleField), title);
    if (performer != null) {
      await tester.enterText(
        find.byKey(SongbookScreen.performerField),
        performer,
      );
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SongbookScreen.confirmAdd));
    await tester.pumpAndSettle();
  }

  group('it is obvious the family sees this', () {
    testWidgets('said at the top, before anything is written', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await open(tester);

      expect(find.byKey(SongbookScreen.everyoneSees), findsOneWidget);
      expect(
        find.textContaining('Everyone in the family sees this'),
        findsOneWidget,
      );
      expect(
        find.textContaining('journal is the private one'),
        findsOneWidget,
        reason: 'the contrast with the journal is the point',
      );
    });

    testWidgets('and removing one says it goes for everybody', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await open(tester);
      await addSong(tester, title: 'Siyahamba');

      final Song song = FamilyEditor.songbook((await family.load())!).single;
      await tester.tap(find.byKey(SongbookScreen.removeFor(song.id)));
      await tester.pumpAndSettle();

      expect(find.textContaining('not just on this phone'), findsOneWidget);
    });
  });

  group('adding a song', () {
    testWidgets('it appears, with who chose it', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      await open(tester);

      await addSong(tester, title: 'Thuma Mina', performer: 'Hugh Masekela');

      expect(find.text('Thuma Mina'), findsOneWidget);
      expect(find.textContaining('Hugh Masekela'), findsOneWidget);
      expect(find.textContaining('Mama'), findsOneWidget);
    });

    testWidgets('the rota is untouched', (WidgetTester tester) async {
      // A song is not a turn.
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      final Family before = (await family.load())!;
      await open(tester);
      await addSong(tester, title: 'Siyahamba');

      final Family after = (await family.load())!;
      expect(after.cycles, hasLength(before.cycles.length));
      expect(after.cycles.single.order, before.cycles.single.order);
    });

    testWidgets('a title of only spaces cannot be submitted', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      await open(tester);

      await tester.tap(find.byKey(SongbookScreen.addSong));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(SongbookScreen.titleField), '   ');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextButton>(find.byKey(SongbookScreen.confirmAdd))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a performer left blank is simply absent', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(mama.id);
      await open(tester);
      await addSong(tester, title: 'Siyahamba', performer: '  ');

      expect((await family.load())!.songs.single.performer, isNull);
    });
  });

  group('taking one out', () {
    testWidgets('declining keeps it', (WidgetTester tester) async {
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await open(tester);
      await addSong(tester, title: 'Siyahamba');

      final Song song = FamilyEditor.songbook((await family.load())!).single;
      await tester.tap(find.byKey(SongbookScreen.removeFor(song.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(find.text('Siyahamba'), findsOneWidget);
    });

    testWidgets('confirming marks it rather than deleting it', (
      WidgetTester tester,
    ) async {
      // Marked, so the removal survives meeting a phone that still has it
      // (ADR-012).
      await family.save(familyOfFour());
      await settings.saveYouAre(jabulile.id);
      await open(tester);
      await addSong(tester, title: 'Siyahamba');

      final Song song = FamilyEditor.songbook((await family.load())!).single;
      await tester.tap(find.byKey(SongbookScreen.removeFor(song.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take it out'));
      await tester.pumpAndSettle();

      final Family after = (await family.load())!;
      expect(FamilyEditor.songbook(after), isEmpty);
      expect(after.songs, hasLength(1));
      expect(after.songs.single.removed, isTrue);
      expect(find.text('Siyahamba'), findsNothing);
    });
  });

  group('before the app knows who you are', () {
    testWidgets('it explains instead of offering a dead button', (
      WidgetTester tester,
    ) async {
      // A song records who chose it, so this phone has to know which person
      // it belongs to. Disabling the button without saying why would be the
      // same information delivered rudely.
      await family.save(familyOfFour());
      await open(tester);

      expect(find.byKey(SongbookScreen.addSong), findsNothing);
      expect(
        find.textContaining('Say which one you are in Settings'),
        findsOneWidget,
      );
    });

    testWidgets('and the button arrives once they have said', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await settings.saveYouAre(tata.id);
      await tester.pumpAndSettle();

      expect(find.byKey(SongbookScreen.addSong), findsOneWidget);
    });
  });

  testWidgets('an empty book says what it is for', (WidgetTester tester) async {
    await family.save(familyOfFour());
    await settings.saveYouAre(jabulile.id);
    await open(tester);

    expect(find.textContaining('always comes back to'), findsOneWidget);
  });

  testWidgets('before there is a family it says so', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(find.text('Set the rota up first'), findsOneWidget);
  });
}
