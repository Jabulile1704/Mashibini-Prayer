import '../../../domain/entities/family.dart';

/// The family as some other device left it.
abstract interface class RemoteFamilySource {
  /// The family as stored remotely, or null if none has been written.
  Future<Family?> fetch();

  /// Publishes [family]. Callers merge before pushing (ADR-008); this writes
  /// what it is given.
  Future<void> push(Family family);

  /// Emits whenever another device changes the family.
  Stream<Family?> watch();
}

/// The document is not one this phone may see.
///
/// Either there is no family with that id or this account is not in it.
/// Firestore answers both with the same refusal and ADR-027 says it should:
/// if the two could be told apart, a family id would be worth something to
/// somebody guessing.
class RemoteRefused implements Exception {
  const RemoteRefused();

  @override
  String toString() => 'RemoteRefused: no family there, or not yours';
}
