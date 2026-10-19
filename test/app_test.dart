import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';

void main() {
  group('MashibiniPrayerApp', () {
    testWidgets('builds and names itself', (WidgetTester tester) async {
      await tester.pumpWidget(const MashibiniPrayerApp());

      expect(find.text('Mashibini Prayer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says what the app is for', (WidgetTester tester) async {
      await tester.pumpWidget(const MashibiniPrayerApp());

      expect(
        find.text('Whose week it is to lead family prayer.'),
        findsOneWidget,
      );
    });

    testWidgets('hides the debug banner', (WidgetTester tester) async {
      await tester.pumpWidget(const MashibiniPrayerApp());

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.debugShowCheckedModeBanner, isFalse);
    });
  });
}
