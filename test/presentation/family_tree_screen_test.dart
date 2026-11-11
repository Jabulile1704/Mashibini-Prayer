import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/family/family_tree.dart';
import 'package:mashibini_prayer/src/presentation/screens/family_member_sheet.dart';
import 'package:mashibini_prayer/src/presentation/screens/family_tree_screen.dart';

import '../support/fake_id_generator.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_photos.dart';
import '../support/family_fixtures.dart';

/// The Family tab (#109).
void main() {
  late LocalFamilyRepository family;
  late LocalDeviceSettingsRepository settings;
  late FakePhotos photos;

  setUp(() {
    final FakeKeyValueStore store = FakeKeyValueStore();
    family = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    photos = FakePhotos();
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
        home: FamilyTreeScreen(
          familyRepository: family,
          settings: settings,
          photos: photos,
          ids: FakeIdGenerator(),
          today: () => anchor,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheetFor(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(FamilyTreeScreen.cellFor(id)));
    await tester.pumpAndSettle();
  }

  Future<void> saveWith(List<Member> members) =>
      family.save(familyOfFour().copyWith(members: members));

  group('who is drawn', () {
    testWidgets('everybody in the family, not only the rota', (
      WidgetTester tester,
    ) async {
      await saveWith(<Member>[
        jabulile,
        sisi,
        mama,
        tata,
        const Member(id: 'm5', displayName: 'Baby', role: 'born 2024'),
      ]);
      await open(tester);

      for (final String id in <String>['m1', 'm2', 'm3', 'm4', 'm5']) {
        expect(find.byKey(FamilyTreeScreen.cellFor(id)), findsOneWidget);
      }
    });

    testWidgets('somebody outside the rota is said to be outside it', (
      WidgetTester tester,
    ) async {
      await saveWith(<Member>[
        jabulile,
        sisi,
        mama,
        tata,
        const Member(id: 'm5', displayName: 'Baby'),
      ]);
      await open(tester);

      expect(find.text('Not in the rota'), findsOneWidget);
    });

    testWidgets('a role replaces the rota line, because they chose it', (
      WidgetTester tester,
    ) async {
      await saveWith(<Member>[
        jabulile.copyWith(role: 'eldest'),
        sisi,
        mama,
        tata,
      ]);
      await open(tester);

      expect(find.text('eldest'), findsOneWidget);
    });

    testWidgets('generations are drawn as separate rows', (
      WidgetTester tester,
    ) async {
      await saveWith(<Member>[
        tata,
        mama,
        jabulile.copyWith(parentIds: <String>['m4', 'm3']),
        sisi.copyWith(parentIds: <String>['m4', 'm3']),
      ]);
      await open(tester);

      final Family stored = (await family.load())!;
      expect(FamilyTree.generations(stored.members), hasLength(2));
      expect(find.byKey(FamilyTreeScreen.comb), findsOneWidget);
      for (final String id in <String>['m1', 'm2', 'm3', 'm4']) {
        expect(find.byKey(FamilyTreeScreen.cellFor(id)), findsOneWidget);
      }
    });

    testWidgets('it says photographs do not leave the phone', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(find.byKey(FamilyTreeScreen.onThisPhone), findsOneWidget);
      expect(find.textContaining('never uploaded'), findsOneWidget);
    });

    testWidgets('before there is a rota it says so', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('Nobody here yet'), findsOneWidget);
      expect(find.byKey(FamilyTreeScreen.comb), findsNothing);
    });
  });

  group('adding somebody to the family', () {
    testWidgets('they appear, and they are not given a week', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      final Family before = (await family.load())!;
      await open(tester);

      await tester.tap(find.byKey(FamilyTreeScreen.addRelative));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(FamilyTreeScreen.nameField), 'Baby');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamilyTreeScreen.confirmAdd));
      await tester.pumpAndSettle();

      final Family after = (await family.load())!;
      expect(after.members, hasLength(5));
      expect(
        after.cycles,
        hasLength(before.cycles.length),
        reason: 'no epoch: nobody has been handed a turn',
      );
      expect(find.text('Baby'), findsOneWidget);
    });

    testWidgets('and the screen says adding somebody is not a turn', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      expect(
        find.textContaining('does not give them a week of prayer'),
        findsOneWidget,
      );
    });

    testWidgets('a name of only spaces is refused', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.tap(find.byKey(FamilyTreeScreen.addRelative));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(FamilyTreeScreen.nameField), '   ');
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextButton>(find.byKey(FamilyTreeScreen.confirmAdd))
            .onPressed,
        isNull,
      );
    });
  });

  group('editing somebody', () {
    testWidgets("a role is kept, in the family's own words", (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await openSheetFor(tester, 'm3');

      await tester.enterText(find.byKey(FamilyMemberSheet.roleField), 'Mama');
      await tester.tap(find.byKey(FamilyMemberSheet.save));
      await tester.pumpAndSettle();

      expect((await family.load())!.membersById['m3']!.role, 'Mama');
    });

    testWidgets('clearing the role removes it rather than storing nothing', (
      WidgetTester tester,
    ) async {
      await saveWith(<Member>[
        jabulile,
        sisi,
        mama.copyWith(role: 'Mama'),
        tata,
      ]);
      await open(tester);
      await openSheetFor(tester, 'm3');

      await tester.enterText(find.byKey(FamilyMemberSheet.roleField), '  ');
      await tester.tap(find.byKey(FamilyMemberSheet.save));
      await tester.pumpAndSettle();

      expect((await family.load())!.membersById['m3']!.role, isNull);
    });

    testWidgets('a parent can be named, and the tree gains a generation', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await openSheetFor(tester, 'm1');

      await tester.tap(find.byKey(FamilyMemberSheet.parentToggle('m4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamilyMemberSheet.save));
      await tester.pumpAndSettle();

      final Family stored = (await family.load())!;
      expect(stored.membersById['m1']!.parentIds, <String>['m4']);
      expect(FamilyTree.generations(stored.members), hasLength(2));
    });

    testWidgets('naming a parent does not touch the rota', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      final Family before = (await family.load())!;
      await open(tester);
      await openSheetFor(tester, 'm1');

      await tester.tap(find.byKey(FamilyMemberSheet.parentToggle('m4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamilyMemberSheet.save));
      await tester.pumpAndSettle();

      final Family after = (await family.load())!;
      expect(after.cycles.length, before.cycles.length);
      expect(after.cycles.single.order, before.cycles.single.order);
    });

    testWidgets('there is a way out that is not a gesture', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await openSheetFor(tester, 'm3');

      expect(find.byKey(FamilyMemberSheet.close), findsOneWidget);

      await tester.enterText(find.byKey(FamilyMemberSheet.roleField), 'Mama');
      await tester.tap(find.byKey(FamilyMemberSheet.close));
      await tester.pumpAndSettle();

      expect(find.byKey(FamilyMemberSheet.roleField), findsNothing);
      expect(
        (await family.load())!.membersById['m3']!.role,
        isNull,
        reason: 'closing is not keeping',
      );
    });

    testWidgets('a name that would close a loop is never offered', (
      WidgetTester tester,
    ) async {
      // The refusal is an absence, not an error message afterwards.
      await saveWith(<Member>[
        jabulile.copyWith(parentIds: <String>['m4']),
        sisi,
        mama,
        tata,
      ]);
      await open(tester);
      await openSheetFor(tester, 'm4');

      expect(find.byKey(FamilyMemberSheet.parentToggle('m1')), findsNothing);
      expect(find.byKey(FamilyMemberSheet.parentToggle('m4')), findsNothing);
      expect(find.byKey(FamilyMemberSheet.parentToggle('m2')), findsOneWidget);
    });
  });

  group('photographs', () {
    testWidgets('choosing one asks the picker for this member', (
      WidgetTester tester,
    ) async {
      photos.next = '/tmp/mashibini/m3-1.jpg';
      await family.save(familyOfFour());
      await open(tester);
      await openSheetFor(tester, 'm3');

      await tester.tap(find.byKey(FamilyMemberSheet.choosePhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamilyMemberSheet.save));
      await tester.pumpAndSettle();

      expect(photos.askedFor, <String>['m3']);
      expect(
        (await family.load())!.membersById['m3']!.photoPath,
        '/tmp/mashibini/m3-1.jpg',
      );
    });

    testWidgets('declining the picker is an ordinary answer', (
      WidgetTester tester,
    ) async {
      photos.next = null;
      await family.save(familyOfFour());
      await open(tester);
      await openSheetFor(tester, 'm3');

      await tester.tap(find.byKey(FamilyMemberSheet.choosePhoto));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(FamilyMemberSheet.removePhoto), findsNothing);
    });

    testWidgets('a picker that will not open is said out loud', (
      WidgetTester tester,
    ) async {
      photos.throws = StateError('no photo library');
      await family.save(familyOfFour());
      await open(tester);
      await openSheetFor(tester, 'm3');

      await tester.tap(find.byKey(FamilyMemberSheet.choosePhoto));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be used'), findsOneWidget);
    });

    testWidgets('one picked and then replaced is not left behind', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await openSheetFor(tester, 'm3');

      photos.next = '/tmp/first.jpg';
      await tester.tap(find.byKey(FamilyMemberSheet.choosePhoto));
      await tester.pumpAndSettle();

      photos.next = '/tmp/second.jpg';
      await tester.tap(find.byKey(FamilyMemberSheet.choosePhoto));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(FamilyMemberSheet.save));
      await tester.pumpAndSettle();

      expect(photos.removed, <String>['/tmp/first.jpg']);
      expect(
        (await family.load())!.membersById['m3']!.photoPath,
        '/tmp/second.jpg',
      );
    });

    testWidgets('removing one clears it', (WidgetTester tester) async {
      await saveWith(<Member>[
        jabulile,
        sisi,
        mama.copyWith(photoPath: '/tmp/mama.jpg'),
        tata,
      ]);
      await open(tester);
      await openSheetFor(tester, 'm3');

      await tester.tap(find.byKey(FamilyMemberSheet.removePhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FamilyMemberSheet.save));
      await tester.pumpAndSettle();

      expect((await family.load())!.membersById['m3']!.photoPath, isNull);
    });
  });
}
