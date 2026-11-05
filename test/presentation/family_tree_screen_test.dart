import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/presentation/screens/family_tree_screen.dart';

import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

/// The Family tab (#109), which is deliberately not what was asked for yet.
///
/// The ask was a hierarchy with a photograph and a role for each person. This
/// is a flat comb of the people in the rota, and the test that matters most
/// here is the one asserting it **says so**. A screen that quietly omits
/// three quarters of a feature is a screen somebody will report as broken.
void main() {
  late LocalFamilyRepository family;

  setUp(() {
    family = LocalFamilyRepository(store: FakeKeyValueStore());
  });

  tearDown(() => family.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: FamilyTreeScreen(familyRepository: family, today: () => anchor),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a cell for everybody in the rota', (WidgetTester tester) async {
    await family.save(familyOfFour());
    await open(tester);

    for (final Member member in <Member>[jabulile, sisi, mama, tata]) {
      expect(find.byKey(FamilyTreeScreen.cellFor(member.id)), findsOneWidget);
      expect(find.text(member.displayName), findsOneWidget);
    }
  });

  testWidgets('each cell carries their initial', (WidgetTester tester) async {
    await family.save(familyOfFour());
    await open(tester);

    // J, S, M, T — the hexagon is where a photograph goes when there is one.
    for (final String initial in <String>['J', 'S', 'M', 'T']) {
      expect(find.text(initial), findsOneWidget);
    }
  });

  testWidgets('and when their turn is', (WidgetTester tester) async {
    await family.save(familyOfFour());
    await open(tester);

    expect(find.text('This week'), findsOneWidget);
  });

  testWidgets('it says what is missing rather than implying it is done', (
    WidgetTester tester,
  ) async {
    await family.save(familyOfFour());
    await open(tester);

    expect(find.byKey(FamilyTreeScreen.notBuiltYet), findsOneWidget);
    expect(find.text('NOT BUILT YET'), findsOneWidget);
    expect(find.textContaining('who is whose parent'), findsOneWidget);
    expect(find.textContaining('photograph and a role'), findsOneWidget);
  });

  testWidgets('a name with no letters in it falls back to a question mark', (
    WidgetTester tester,
  ) async {
    // `characters.first` throws on an empty string. Not reachable through
    // the UI — the add dialog trims and refuses empty — but a family can
    // arrive from a merge with another phone, and a screen is the wrong
    // place to discover it.
    //
    // Written as a real family with a real blank name rather than as
    // `expect(takeException(), isNull)` on a healthy one, which was the
    // first version and would have passed with the bug present.
    await family.save(
      Family(
        id: 'f1',
        name: 'Mashibini',
        members: const <Member>[
          Member(id: 'm1', displayName: '   '),
          Member(id: 'm2', displayName: 'Sisi'),
        ],
        cycles: familyOfFour().cycles,
      ),
    );
    await open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('before there is a rota it says so', (WidgetTester tester) async {
    await open(tester);

    expect(find.text('Nobody here yet'), findsOneWidget);
    expect(find.byKey(FamilyTreeScreen.comb), findsNothing);
  });
}
