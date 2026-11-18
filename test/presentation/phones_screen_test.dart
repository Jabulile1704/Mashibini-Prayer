import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/app.dart';
import 'package:mashibini_prayer/src/application/join_a_family.dart';
import 'package:mashibini_prayer/src/data/repositories/device_settings_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/local_family_repository.dart';
import 'package:mashibini_prayer/src/data/repositories/syncing_family_repository.dart';
import 'package:mashibini_prayer/src/data/sources/platform/identity.dart';
import 'package:mashibini_prayer/src/data/sources/remote/remote_family_source.dart';
import 'package:mashibini_prayer/src/domain/entities/cycle.dart';
import 'package:mashibini_prayer/src/domain/entities/family.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/presentation/screens/phones_screen.dart';

import '../support/fake_identity.dart';
import '../support/fake_key_value_store.dart';
import '../support/fake_remote_family_source.dart';
import '../support/fake_remote_membership.dart';
import '../support/fake_sharing.dart';
import '../support/family_fixtures.dart';

/// The screen both halves of a join happen on (#143).
void main() {
  const SignedIn sisiAccount = SignedIn(
    uid: 'kJ8sQ2mNpR4tVwXyZa1bCd3e',
    displayName: 'Sisi',
  );
  const String theirCode = 'fqx7n2bkrmdh';

  late FakeKeyValueStore store;
  late LocalFamilyRepository onThisPhone;
  late SyncingFamilyRepository repository;
  late LocalDeviceSettingsRepository settings;
  late FakeRemoteMembership memberships;
  late FakeSharing sharing;
  late FakeIdentity identity;
  late Map<String, FakeRemoteFamilySource> remotes;

  FakeRemoteFamilySource remoteFor(String familyId) =>
      remotes.putIfAbsent(familyId, () => FakeRemoteFamilySource());

  Family theirFamily() => Family(
    id: theirCode,
    name: 'Mashibini',
    members: <Member>[
      jabulile.copyWith(uid: 'uid-jabulile'),
      sisi.copyWith(uid: sisiAccount.uid),
      mama,
    ],
    cycles: <Cycle>[
      Cycle(
        id: 'c1',
        effectiveFrom: anchor,
        order: const <String>['m1', 'm2', 'm3'],
      ),
    ],
  );

  setUp(() {
    store = FakeKeyValueStore();
    onThisPhone = LocalFamilyRepository(store: store);
    settings = LocalDeviceSettingsRepository(store: store);
    memberships = FakeRemoteMembership();
    sharing = FakeSharing();
    identity = FakeIdentity(signedIn: sisiAccount);
    remotes = <String, FakeRemoteFamilySource>{};
    repository = SyncingFamilyRepository(
      local: onThisPhone,
      remoteFor: remoteFor,
    );
  });

  tearDown(() async {
    await repository.dispose();
    await settings.dispose();
  });

  Future<void> open(WidgetTester tester, {bool withFirebase = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocales.delegates,
        supportedLocales: AppLocales.supported,
        locale: const Locale('en', 'ZA'),
        home: PhonesScreen(
          familyRepository: repository,
          identity: identity,
          sharing: sharing,
          join: withFirebase
              ? JoinAFamily(
                  families: repository,
                  settings: settings,
                  memberships: memberships,
                  identity: identity,
                  remoteFor: remoteFor,
                )
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The screen is longer than a phone, and a ListView does not build what
  /// it has not scrolled to.
  Future<void> reach(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
  }

  group('with nobody signed in', () {
    testWidgets('it says so rather than showing an empty form', (
      WidgetTester tester,
    ) async {
      identity = FakeIdentity();
      await open(tester);

      expect(find.text('Sign in first'), findsOneWidget);
    });
  });

  group('a phone waiting to be let in', () {
    testWidgets('shows the code somebody else has to add', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text(sisiAccount.uid), findsOneWidget);
    });

    testWidgets('and sends it without anybody reading it aloud', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(find.byKey(PhonesScreen.sendMyCode));
      await tester.pumpAndSettle();

      expect(sharing.shares, 1);
      expect(sharing.sharedText, contains(sisiAccount.uid));
    });

    testWidgets('joins with the family code', (WidgetTester tester) async {
      remoteFor(theirCode).stored = theirFamily();
      await open(tester);

      await tester.enterText(
        find.byKey(PhonesScreen.familyCodeField),
        theirCode,
      );
      await tester.tap(find.byKey(PhonesScreen.joinButton));
      await tester.pumpAndSettle();

      expect((await onThisPhone.load())!.id, theirCode);
      expect(find.textContaining('Joined Mashibini'), findsOneWidget);
    });

    testWidgets('is told plainly when nobody has added it yet', (
      WidgetTester tester,
    ) async {
      remoteFor(theirCode).failOnFetch = const RemoteRefused();
      await open(tester);

      await tester.enterText(
        find.byKey(PhonesScreen.familyCodeField),
        theirCode,
      );
      await tester.tap(find.byKey(PhonesScreen.joinButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('has to add this account'), findsOneWidget);
    });

    testWidgets('and a typo never reaches the network', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.enterText(find.byKey(PhonesScreen.familyCodeField), 'f1');
      await tester.tap(find.byKey(PhonesScreen.joinButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('not a family code'), findsOneWidget);
      expect(remotes, isEmpty);
    });
  });

  group('a phone already in a family', () {
    setUp(() async {
      await onThisPhone.save(familyOfFour());
    });

    testWidgets('offers everybody, so nobody gets in unnamed', (
      WidgetTester tester,
    ) async {
      await open(tester);

      for (final Member member in familyOfFour().members) {
        expect(
          find.byKey(PhonesScreen.admitRow(member.id)),
          findsOneWidget,
          reason: member.displayName,
        );
      }
      expect(find.byKey(PhonesScreen.familyCodeField), findsNothing);
    });

    testWidgets('admits one by pasting their code', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(find.byKey(PhonesScreen.admitRow('m2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(PhonesScreen.admitField),
        sisiAccount.uid,
      );
      await tester.tap(find.byKey(PhonesScreen.admitConfirm));
      await tester.pumpAndSettle();

      expect(
        (await onThisPhone.load())!.membersById['m2']!.uid,
        sisiAccount.uid,
      );
    });

    testWidgets('a half-copied code is refused before it is saved', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(find.byKey(PhonesScreen.admitRow('m2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(PhonesScreen.admitField), 'kJ8sQ2');
      await tester.tap(find.byKey(PhonesScreen.admitConfirm));
      await tester.pumpAndSettle();

      expect(find.textContaining('not look like a whole code'), findsOneWidget);
      expect((await onThisPhone.load())!.membersById['m2']!.uid, isNull);
    });

    testWidgets('one account cannot be two people', (
      WidgetTester tester,
    ) async {
      await onThisPhone.save(
        familyOfFour().copyWith(
          members: <Member>[
            jabulile.copyWith(uid: sisiAccount.uid),
            sisi,
            mama,
            tata,
          ],
        ),
      );
      await open(tester);

      await tester.tap(find.byKey(PhonesScreen.admitRow('m2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(PhonesScreen.admitField),
        sisiAccount.uid,
      );
      await tester.tap(find.byKey(PhonesScreen.admitConfirm));
      await tester.pumpAndSettle();

      expect(find.textContaining('already belongs to'), findsOneWidget);
    });

    testWidgets('and sends the family code, which is not a password', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await reach(tester, PhonesScreen.sendFamilyCode);

      await tester.tap(find.byKey(PhonesScreen.sendFamilyCode));
      await tester.pumpAndSettle();

      expect(sharing.sharedText, contains('f1'));
    });
  });

  group('a phone that already has a rota and joins another family', () {
    setUp(() async {
      await onThisPhone.save(familyOfFour());
      remoteFor(theirCode).stored = theirFamily();
    });

    Future<void> typeAndJoin(WidgetTester tester) async {
      await reach(tester, PhonesScreen.familyCodeField);
      await tester.enterText(
        find.byKey(PhonesScreen.familyCodeField),
        theirCode,
      );
      await reach(tester, PhonesScreen.joinButton);
      await tester.tap(find.byKey(PhonesScreen.joinButton));
      await tester.pumpAndSettle();
    }

    testWidgets('the way in is still offered, not hidden', (
      WidgetTester tester,
    ) async {
      // Hiding it would make `WouldReplaceThisRota` unreachable, which is
      // the shape R1.4 and R2.3 both carried for days.
      await open(tester);
      await reach(tester, PhonesScreen.familyCodeField);

      expect(find.byKey(PhonesScreen.familyCodeField), findsOneWidget);
      expect(find.text('Join a different family'), findsOneWidget);
    });

    testWidgets('is asked, and told what it is giving up', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await typeAndJoin(tester);

      expect(find.text('Put this rota aside?'), findsOneWidget);
      // Inside the dialog specifically: the screen's own helper text says
      // the same thing, which is the point, so a bare text finder matches
      // twice and proves nothing about the dialog.
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('cannot be merged'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Your journal stays'), findsOneWidget);
    });

    testWidgets('and nothing happens if it says no', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await typeAndJoin(tester);

      await tester.tap(find.text('Keep this one'));
      await tester.pumpAndSettle();

      expect((await onThisPhone.load())!.id, 'f1');
    });

    testWidgets('and joins once it has said yes', (WidgetTester tester) async {
      await open(tester);
      await typeAndJoin(tester);

      await tester.tap(find.byKey(PhonesScreen.confirmReplace));
      await tester.pumpAndSettle();

      expect((await onThisPhone.load())!.id, theirCode);
    });
  });

  group('without Firebase', () {
    testWidgets('joining says so rather than failing silently', (
      WidgetTester tester,
    ) async {
      await open(tester, withFirebase: false);

      await tester.enterText(
        find.byKey(PhonesScreen.familyCodeField),
        theirCode,
      );
      await tester.tap(find.byKey(PhonesScreen.joinButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot reach the family'), findsOneWidget);
    });
  });
}
