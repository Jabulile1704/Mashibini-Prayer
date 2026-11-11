import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Who this phone's owner is, to Firebase (#76).
abstract interface class Identity {
  /// The person signed in on this phone, or null.
  SignedIn? get current;

  /// Emits whenever that changes, starting with the current value.
  Stream<SignedIn?> watch();

  /// Opens the sign-in sheet.
  Future<SignedIn?> signIn();

  Future<void> signOut();
}

/// A signed-in person: the uid the security rules care about, and a name to
/// show so nobody has to recognise themselves by a uid.
class SignedIn {
  const SignedIn({required this.uid, this.displayName, this.email});

  final String uid;
  final String? displayName;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is SignedIn &&
      other.uid == uid &&
      other.displayName == displayName &&
      other.email == email;

  @override
  int get hashCode => Object.hash(uid, displayName, email);

  @override
  String toString() => 'SignedIn($uid, ${displayName ?? email ?? 'no name'})';
}

/// Nobody is signed in, and nobody can be.
class NoIdentity implements Identity {
  const NoIdentity();

  @override
  SignedIn? get current => null;

  @override
  Stream<SignedIn?> watch() => Stream<SignedIn?>.value(null);

  @override
  Future<SignedIn?> signIn() async =>
      throw StateError('Signing in is not available on this phone');

  @override
  Future<void> signOut() async {}
}

/// Firebase Authentication, with Google as the only provider.
class FirebaseIdentity implements Identity {
  FirebaseIdentity({FirebaseAuth? auth}) : _given = auth;

  final FirebaseAuth? _given;

  /// **Resolved on first use, not in the constructor.**
  late final FirebaseAuth _auth = _given ?? FirebaseAuth.instance;

  @override
  SignedIn? get current => _fromUser(_auth.currentUser);

  @override
  Stream<SignedIn?> watch() => _auth.authStateChanges().map(_fromUser);

  @override
  Future<SignedIn?> signIn() async {
    final GoogleSignIn google = GoogleSignIn.instance;
    await google.initialize();

    final GoogleSignInAccount account = await google.authenticate();
    final GoogleSignInAuthentication tokens = account.authentication;

    final UserCredential credential = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: tokens.idToken),
    );
    return _fromUser(credential.user);
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  static SignedIn? _fromUser(User? user) => user == null
      ? null
      : SignedIn(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
        );
}
