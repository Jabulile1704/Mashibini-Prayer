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

  Future<void> show(
    WidgetTester tester,
    SayingForTheDay sayings, {
    bool canSync = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: AboutScreen(
          appVersion: FakeAppVersion(),
          canSync: canSync,
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

  group('what it says it can do (#157)', () {
    /// Scrolls to [text], which is below the fold on a test surface.
    Future<void> reach(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(find.text(text), 160);
      await tester.pumpAndSettle();
    }

    testWidgets('a build that syncs does not say the phones cannot', (
      WidgetTester tester,
    ) async {
      await show(tester, given(reviewed: false), canSync: true);

      // The sentence that was true for thirty-four days and then shipped
      // into a release that had made it false, held in place by a test.
      expect(find.textContaining('do not see each other'), findsNothing);
    });

    testWidgets('and says what it does instead', (WidgetTester tester) async {
      await show(tester, given(reviewed: false), canSync: true);
      await reach(tester, 'The phones share one rota');

      expect(find.text('The phones share one rota'), findsOneWidget);
      expect(
        find.textContaining('no code that lets a stranger in'),
        findsOneWidget,
        reason: 'ADR-027, where somebody is deciding whether to send a code',
      );
    });

    testWidgets('a build that cannot sync still says so', (
      WidgetTester tester,
    ) async {
      await show(tester, given(reviewed: false));
      await reach(tester, 'The phones do not see each other');

      expect(find.text('The phones do not see each other'), findsOneWidget);
      expect(find.text('The phones share one rota'), findsNothing);
    });

    testWidgets('the journal is still only here, and it says the rota is not', (
      WidgetTester tester,
    ) async {
      await show(tester, given(reviewed: false), canSync: true);
      await reach(tester, 'Reinstalling loses your journal');

      // The asymmetry v2.2.0 created: the part anybody could retype
      // survives, the part nobody can does not.
      expect(find.textContaining('The rota comes back'), findsOneWidget);
      expect(find.textContaining('never anywhere else'), findsOneWidget);
    });

    testWidgets('and the privacy promise is unchanged by syncing', (
      WidgetTester tester,
    ) async {
      await show(tester, given(reviewed: false), canSync: true);
      await reach(tester, 'Your journal stays on your phone');

      expect(find.textContaining('neither can we'), findsOneWidget);
      expect(find.textContaining('the journal never does'), findsOneWidget);
    });
  });
}
