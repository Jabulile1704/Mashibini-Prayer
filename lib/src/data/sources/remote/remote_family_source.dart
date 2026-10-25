import '../../../domain/entities/family.dart';

/// The family as some other device left it.
///
/// Deliberately expressed in domain types and deliberately empty of any
/// mention of Firestore: this is the seam ADR-003 described, and the point of
/// it is that everything above can be written, tested and shipped before the
/// thing behind it exists.
///
/// No implementation yet. Creating a Firebase project needs the owner's own
/// Google account — see `docs/FIREBASE-SETUP.md` — and a stub pretending to
/// be one would make the repository look finished while failing on the first
/// real device.
abstract interface class RemoteFamilySource {
  /// The family as stored remotely, or null if none has been written.
  Future<Family?> fetch();

  /// Publishes [family]. Callers merge before pushing (ADR-008); this writes
  /// what it is given.
  Future<void> push(Family family);

  /// Emits whenever another device changes the family.
  Stream<Family?> watch();
}
