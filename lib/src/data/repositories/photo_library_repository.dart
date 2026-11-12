import 'dart:convert';

import '../sources/local/key_value_store.dart';

/// Which members have a photograph **on this phone** (#140).
///
/// The path is deliberately not a field on a member. A member record is
/// shared with the rest of the family (R6.2), and a path into this phone's
/// application directory means nothing on anybody else's handset. Songs made
/// the same split first, in `AudioLibraryRepository`.
class PhotoLibraryRepository {
  PhotoLibraryRepository({required this.store});

  final KeyValueStore store;

  static const String key = 'device.photos.v1';

  /// Every photograph on this phone, by member id.
  Future<Map<String, String>> all() async {
    final String? stored = await store.read(key);
    if (stored == null || stored.isEmpty) {
      return <String, String>{};
    }
    final Object? decoded = jsonDecode(stored);
    if (decoded is! Map<String, Object?>) {
      return <String, String>{};
    }
    return <String, String>{
      for (final MapEntry<String, Object?> entry in decoded.entries)
        if (entry.value case final String path) entry.key: path,
    };
  }

  Future<String?> pathFor(String memberId) async => (await all())[memberId];

  Future<void> remember(String memberId, String path) async {
    final Map<String, String> paths = await all()
      ..[memberId] = path;
    await store.write(key, jsonEncode(paths));
  }

  /// Forgets the photograph for a member. Missing is not an error.
  Future<void> forget(String memberId) async {
    final Map<String, String> paths = await all()
      ..remove(memberId);
    await store.write(key, jsonEncode(paths));
  }

  /// Takes in photographs that were stored on member records before #140,
  /// keeping whatever this phone already knows.
  Future<void> adopt(Map<String, String> paths) async {
    if (paths.isEmpty) {
      return;
    }
    final Map<String, String> merged = <String, String>{
      ...paths,
      ...await all(),
    };
    await store.write(key, jsonEncode(merged));
  }
}
