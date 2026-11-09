import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Who this phone's owner is, to Firebase (#76).
///
/// Behind a seam for the usual reason — a widget test cannot open Google's
/// sign-in sheet — and because **the decision about what signing in means
/// is not this class's**. It returns a uid and a display name; whether that
/// uid gets attached to a member of the family is the app's business
/// (ADR-023).
///
/// Google rather than email and password, and never an email link: ADR-010
/// records that the free tier allows five link emails a day across the whole
/// project, which is one person retrying on a bad evening and then nobody
/// being able to sign in at all.
abstract interface class Identity {
  /// The person signed in on this phone, or null.
  SignedIn? get current;

  /// Emits whenever that changes, starting with the current value.
  Stream<SignedIn?> watch();

  /// Opens the sign-in sheet.
  ///
  /// Returns null if it was dismissed, which is an ordinary answer rather
  /// than a failure — somebody opening Settings to look is not somebody who
  /// has decided to sign in.
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

/// Firebase Authentication, with Google as the only provider.
class FirebaseIdentity implements Identity {
  FirebaseIdentity({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  SignedIn? get current => _fromUser(_auth.currentUser);

  @override
  Stream<SignedIn?> watch() => _auth.authStateChanges().map(_fromUser);

  @override
  Future<SignedIn?> signIn() async {
    // `google_sign_in` 7 requires initialising before authenticating, and
    // calling it twice is harmless — which is what lets this stay a plain
    // method rather than something the caller has to sequence.
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
