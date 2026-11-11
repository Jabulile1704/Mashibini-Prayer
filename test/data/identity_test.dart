import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/data/sources/platform/identity.dart';

/// The bug that shipped to a phone on Day 27.
void main() {
  group('constructing it must not need Firebase', () {
    test('it does not throw before anything is asked of it', () {
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
      expect(await identity.watch().first, isNull);
    });

    test('signing in refuses, and says why', () async {
      expect(identity.signIn(), throwsStateError);
    });

    test('signing out is harmless', () async {
      await expectLater(identity.signOut(), completes);
    });
  });
}
