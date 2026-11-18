import '../serialization/family_json.dart';
import '../sources/local/key_value_store.dart';
import '../../domain/entities/family.dart';
import '../../domain/ids.dart';
import '../repositories/local_family_repository.dart';

/// Gives a family created before #148 an id of its own.
///
/// Every family the setup screen built carried the literal `f1`, because
/// nothing read the id: it distinguished one family from the others inside
/// a single phone's storage, where there are none. Day 32 made it the
/// Firestore document path, at which point every family in the world began
/// writing to `families/f1`.
///
/// Deletable: once no install predates #148 this does nothing.
abstract final class TheFamilyNeedsItsOwnId {
  /// The only id the hardcode could ever have produced.
  static const String hardcoded = 'f1';

  static Future<void> run({
    required KeyValueStore store,
    required IdGenerator ids,
  }) async {
    final String? stored = await store.read(LocalFamilyRepository.storageKey);
    if (stored == null || stored.isEmpty) {
      return;
    }

    final Family family;
    try {
      family = FamilyJson.decode(stored);
    } on FormatException {
      // A document this build cannot read is not one to rewrite.
      return;
    }

    // Exactly `f1`, and nothing else.
    //
    // A family whose id came from the generator is already right. A family
    // this phone **joined** carries the id of the phone it joined, and
    // renaming that would quietly detach it from the family it belongs to —
    // which is a worse outcome than the one being fixed.
    if (family.id != hardcoded) {
      return;
    }

    await store.write(
      LocalFamilyRepository.storageKey,
      FamilyJson.encode(_renamed(family, ids.newId('f'))),
    );
  }

  /// A family is immutable and `copyWith` deliberately cannot change an id.
  static Family _renamed(Family family, String id) => Family(
    id: id,
    name: family.name,
    members: family.members,
    cycles: family.cycles,
    skips: family.skips,
    songs: family.songs,
    schemaVersion: family.schemaVersion,
  );
}
