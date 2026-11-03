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
  ///
  /// `pumpAndSettle` alone is not enough and the first version of these
  /// tests used it: it pumps only while frames are *scheduled*, and a
  /// static splash schedules none, so the 650ms timer never fires and the
  /// gate never opens. Time has to be advanced explicitly.
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

      // Drained before the test ends. A pending timer at teardown is a
      // failure in flutter_test, and rightly — a widget that leaves one
      // behind is a widget that keeps working after it is gone.
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
      // A splash exists to cover work. One that outlasts the work is an
      // animation somebody sits through every morning, so this pins the
      // budget rather than trusting the constant not to grow.
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
      // Nothing saved. The read returns null, which is an answer — a splash
      // that waits for data rather than for the read would hang here
      // forever on the one launch that matters most.
      await open(tester);
      await settlePast(tester);

      expect(find.text('the rota'), findsOneWidget);
    });
  });
}
