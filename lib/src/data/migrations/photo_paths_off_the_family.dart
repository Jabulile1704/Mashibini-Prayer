import 'dart:convert';

import '../repositories/local_family_repository.dart';
import '../repositories/photo_library_repository.dart';
import '../serialization/family_json.dart';
import '../sources/local/key_value_store.dart';

/// Moves member photographs out of the shared family document and into this
/// phone's own store (#140).
///
/// Runs once, before anything reads the family. Everybody who chose a
/// photograph before this build has it recorded on the member, which is the
/// one place it must not be once the document starts syncing (R6.2).
///
/// Deletable: once no install predates #140 this does nothing, and the whole
/// file can go.
abstract final class PhotoPathsOffTheFamily {
  static const String doneKey = 'device.photos.migrated.v1';

  static Future<void> run({
    required KeyValueStore store,
    required PhotoLibraryRepository photos,
  }) async {
    if (await store.read(doneKey) != null) {
      return;
    }

    final String? stored = await store.read(LocalFamilyRepository.storageKey);
    if (stored != null && stored.isNotEmpty) {
      await _rescue(stored, store: store, photos: photos);
    }

    await store.write(doneKey, 'done');
  }

  /// Keeps the photographs, then rewrites the document without them.
  static Future<void> _rescue(
    String stored, {
    required KeyValueStore store,
    required PhotoLibraryRepository photos,
  }) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      // A document that cannot be read has no photographs to rescue, and
      // failing here would stop the app starting.
      return;
    }
    if (decoded is! Map<String, Object?>) {
      return;
    }

    await photos.adopt(FamilyJson.devicePhotosIn(decoded));

    try {
      await store.write(
        LocalFamilyRepository.storageKey,
        FamilyJson.encode(FamilyJson.fromMap(decoded)),
      );
    } on FormatException {
      // The path is out of harm's way either way: it is only published by a
      // save, and a document this build cannot parse is never saved.
    }
  }
}
