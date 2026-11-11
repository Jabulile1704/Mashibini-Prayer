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
