import '../../domain/entities/family.dart';

/// What the application layer asks for a family.
abstract interface class FamilyRepository {
  /// The family as last stored, or null if none has been set up.
  Future<Family?> load();

  Future<void> save(Family family);

  /// Emits whenever the stored family changes, starting with the current one.
  Stream<Family?> watch();

  Future<void> clear();

  Future<void> dispose();
}
