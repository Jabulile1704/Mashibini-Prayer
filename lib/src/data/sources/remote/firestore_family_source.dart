import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/entities/family.dart';
import '../../serialization/family_json.dart';
import 'remote_family_source.dart';

/// The family as Firestore holds it (#75).
///
/// Thin on purpose. Everything that decides what a family document contains
/// lives in `FamilyJson`, where it is tested without a network, and
/// everything that decides who may read it lives in `firestore.rules`, where
/// it is tested against the emulator. What is left here is one document
/// reference and three calls.
class FirestoreFamilySource implements RemoteFamilySource {
  FirestoreFamilySource({required this.familyId, required this._firestore});

  /// The collection the rules are written against.
  static const String collection = 'families';

  final String familyId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _document =>
      _firestore.collection(collection).doc(familyId);

  @override
  Future<Family?> fetch() async => _read(await _document.get());

  @override
  Future<void> push(Family family) async {
    if (family.id != familyId) {
      throw ArgumentError.value(
        family.id,
        'family.id',
        'this source publishes $familyId and nothing else',
      );
    }
    await _document.set(FamilyJson.toMap(family));
  }

  /// Our own writes come back through here too. The caller merges, which
  /// makes that harmless rather than something to filter out.
  @override
  Stream<Family?> watch() => _document.snapshots().map(_read);

  static Family? _read(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final Map<String, dynamic>? data = snapshot.data();
    return data == null ? null : FamilyJson.fromMap(data);
  }
}
