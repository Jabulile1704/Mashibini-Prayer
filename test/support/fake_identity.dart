import 'dart:async';

import 'package:mashibini_prayer/src/data/sources/platform/identity.dart';

/// Signing in without Google.
class FakeIdentity implements Identity {
  FakeIdentity({SignedIn? signedIn, this.next, this.throws})
    : _current = signedIn {
    _controller.add(_current);
  }

  SignedIn? next;
  Object? throws;

  SignedIn? _current;
  final StreamController<SignedIn?> _controller =
      StreamController<SignedIn?>.broadcast();

  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  SignedIn? get current => _current;

  @override
  Stream<SignedIn?> watch() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<SignedIn?> signIn() async {
    signInCalls++;
    final Object? error = throws;
    if (error != null) {
      throw error;
    }
    _current = next;
    _controller.add(_current);
    return _current;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    _controller.add(null);
  }
}
