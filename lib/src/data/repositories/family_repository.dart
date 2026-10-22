import '../../domain/entities/family.dart';

/// What the application layer asks for a family.
///
/// Expressed entirely in domain types: nothing here mentions JSON, a file, a
/// preference key or Firestore. That is the seam ADR-003 relies on — the
/// local store is the read path today, and a remote source writes into it
/// later, without the layers above noticing either.
abstract interface class FamilyRepository {
  /// The family as last stored, or null if none has been set up.
  ///
  /// Null is an ordinary answer, not a failure: before setup there is no
  /// family, and the UI has a first-run state for exactly that.
  Future<Family?> load();

  Future<void> save(Family family);

  /// Emits whenever the stored family changes, starting with the current one.
  ///
  /// Broadcast, so several screens can listen. Callers cancel their
  /// subscriptions; [dispose] closes the stream.
  Stream<Family?> watch();

  Future<void> clear();

  Future<void> dispose();
}
