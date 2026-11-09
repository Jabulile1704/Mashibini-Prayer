import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/sources/platform/identity.dart';

/// The bug that shipped to a phone on Day 27.
///
/// `FirebaseIdentity`'s constructor read `FirebaseAuth.instance`, which
/// throws `[core/no-app]` until `Firebase.initializeApp()` has run — and
/// that call did not exist anywhere in the app. `main()` died before
/// `runApp`, so the native launch screen stayed up for ever. It was
/// reported as "the app is taking a while to launch", which is exactly what
/// it looks like from outside.
///
/// **Nothing caught it**, and the reason is worth more than the fix: every
/// widget test injects `FakeIdentity`, so the only code that ever builds
/// the real one is `main()` — the one file with no test at all. The seam
/// that makes this app testable is the same seam that hid the wiring.
///
/// These tests run with Firebase **not** initialised, which is the state
/// the test binding is always in. That is the whole point: the condition
/// that broke the app is this suite's default.
void main() {
  group('constructing it must not need Firebase', () {
    test('it does not throw before anything is asked of it', () {
      // The regression, directly. Firebase is not initialised here, and
      // building the object must still be safe — because `main()` builds
      // it before it has anything to say about auth.
      expect(FirebaseIdentity.new, returnsNormally);
    });

    test('and building it twice is still fine', () {
      expect(FirebaseIdentity.new, returnsNormally);
      expect(FirebaseIdentity.new, returnsNormally);
    });
  });

  group('when Firebase cannot start at all', () {
    const Identity identity = NoIdentity();

    test('nobody is signed in', () {
      expect(identity.current, isNull);
    });

    test('and the stream says so rather than hanging', () async {
      // A stream that never emits would leave the Settings row building
      // for ever, which is the same failure wearing different clothes.
      expect(await identity.watch().first, isNull);
    });

    test('signing in refuses, and says why', () async {
      // Refuses rather than silently doing nothing: a sign-in button that
      // appears to work and does not is worse than one that explains.
      expect(identity.signIn(), throwsStateError);
    });

    test('signing out is harmless', () async {
      await expectLater(identity.signOut(), completes);
    });
  });
}
