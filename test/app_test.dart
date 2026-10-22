import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';

import 'support/fake_key_value_store.dart';

void main() {
  late LocalFamilyRepository repository;

  setUp(() {
    repository = LocalFamilyRepository(store: FakeKeyValueStore());
  });

  tearDown(() async => repository.dispose());

  group('MashibiniPrayerApp', () {
    testWidgets('builds and names itself', (WidgetTester tester) async {
      await tester.pumpWidget(MashibiniPrayerApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Mashibini Prayer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides the debug banner', (WidgetTester tester) async {
      await tester.pumpWidget(MashibiniPrayerApp(repository: repository));

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('opens on the rota, not a placeholder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MashibiniPrayerApp(repository: repository));
      await tester.pumpAndSettle();

      // Nothing is set up yet, so the first thing a new install shows is the
      // invitation to set one up.
      expect(find.text('No rota yet'), findsOneWidget);
    });
  });
}
