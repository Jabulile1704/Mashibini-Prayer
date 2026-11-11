import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/domain/entities/saying.dart';
import 'package:mashibini_prayer/src/domain/saying/saying_for_the_day.dart';
import 'package:mashibini_prayer/src/presentation/screens/about_screen.dart';

import '../support/fake_app_version.dart';

/// Where the sayings come from, said in the app rather than in a repository.
void main() {
  SayingForTheDay given({required bool reviewed, List<String>? languages}) =>
      SayingForTheDay(
        source: SayingSource(
          tradition: 'Southern African',
          languages: languages ?? const <String>['isiXhosa', 'Sesotho'],
          notice: 'Carried orally and attributed to the language.',
          reviewed: reviewed,
        ),
        sayings: const <Saying>[
          Saying(
            text: 'A person is a person through other people.',
            original: 'Umntu ngumntu ngabantu',
            language: 'isiXhosa',
          ),
          Saying(
            text: 'Hands wash one another.',
            original: 'Matsogo a hlatswana',
            language: 'Sesotho',
          ),
        ],
      );

  Future<void> show(WidgetTester tester, SayingForTheDay sayings) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: AboutScreen(
          appVersion: FakeAppVersion(),
          sayings: Future<SayingForTheDay>.value(sayings),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it names the tradition, the count and the languages', (
    WidgetTester tester,
  ) async {
    await show(tester, given(reviewed: false));

    await tester.scrollUntilVisible(
      find.text('Where the sayings come from'),
      160,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 Southern African sayings'), findsOneWidget);
    expect(find.textContaining('isiXhosa and Sesotho'), findsOneWidget);
  });

  testWidgets('three languages read as a sentence, not a list', (
    WidgetTester tester,
  ) async {
    await show(
      tester,
      given(
        reviewed: false,
        languages: const <String>['isiXhosa', 'isiZulu', 'Sesotho'],
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Where the sayings come from'),
      160,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('isiXhosa, isiZulu and Sesotho'),
      findsOneWidget,
    );
  });

  testWidgets('unchecked wording says so, in the app', (
    WidgetTester tester,
  ) async {
    await show(tester, given(reviewed: false));

    await tester.scrollUntilVisible(
      find.text('Where the sayings come from'),
      160,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('has checked the spelling'), findsOneWidget);
  });

  testWidgets('once a speaker has checked it, the apology goes away', (
    WidgetTester tester,
  ) async {
    await show(tester, given(reviewed: true));

    await tester.scrollUntilVisible(
      find.text('Where the sayings come from'),
      160,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('has checked the spelling'), findsNothing);
    expect(
      find.textContaining('2 Southern African sayings'),
      findsOneWidget,
      reason: 'the provenance itself is not conditional',
    );
  });
}
