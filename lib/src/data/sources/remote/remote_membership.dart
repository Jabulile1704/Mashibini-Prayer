import 'package:cloud_firestore/cloud_firestore.dart';

/// Which family an account says it belongs to (#75).
///
/// A phone that is wiped and reinstalled has the account and nothing else.
/// This is the one thing it can ask for by a name it already knows — its own
/// uid — and the answer is the family id it needs to fetch anything.
abstract interface class RemoteMembership {
  /// The family [uid] last said it was in, or null.
  Future<String?> familyIdFor(String uid);

  /// Records that [uid] is in [familyId]. Overwrites whatever was there.
  Future<void> remember({required String uid, required String familyId});
}

class FirestoreMembership implements RemoteMembership {
  FirestoreMembership({required this._firestore});

  /// The collection the rules are written against.
  static const String collection = 'memberships';

  static const String field = 'familyId';

  final FirebaseFirestore _firestore;

  @override
  Future<String?> familyIdFor(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(collection)
        .doc(uid)
        .get();
    final Object? value = snapshot.data()?[field];
    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  Future<void> remember({required String uid, required String familyId}) async {
    await _firestore.collection(collection).doc(uid).set(<String, Object?>{
      field: familyId,
    });
  }
}
