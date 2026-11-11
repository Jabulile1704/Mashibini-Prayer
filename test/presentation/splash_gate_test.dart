import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/presentation/brand/mark.dart';
import 'package:mashibini_prayer/src/presentation/screens/splash_gate.dart';

import '../support/fake_key_value_store.dart';
import '../support/family_fixtures.dart';

void main() {
  late LocalFamilyRepository family;

  /// Advances past the splash's own minimum, then lets the crossfade run.
  Future<void> settlePast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  setUp(() => family = LocalFamilyRepository(store: FakeKeyValueStore()));
  tearDown(() async => family.dispose());

  Future<void> open(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: SplashGate(
        repository: family,
        child: const Scaffold(body: Center(child: Text('the rota'))),
      ),
    ),
  );

  group('covering the cold start', () {
    testWidgets('the mark is held while the first read happens', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await tester.pump();

      expect(find.text('the rota'), findsNothing);
      expect(find.byType(RotaMark), findsOneWidget);

      await settlePast(tester);
    });

    testWidgets('the app appears once it is ready', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);
      await settlePast(tester);

      expect(find.text('the rota'), findsOneWidget);
    });

    testWidgets('it does not outlast its own minimum by much', (
      WidgetTester tester,
    ) async {
      await family.save(familyOfFour());
      await open(tester);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('the rota'), findsNothing, reason: 'still holding');

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('the rota'), findsOneWidget);
      expect(find.byType(RotaMark), findsNothing);
    });

    testWidgets('a first run with nothing stored still resolves', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await settlePast(tester);

      expect(find.text('the rota'), findsOneWidget);
    });
  });
}
