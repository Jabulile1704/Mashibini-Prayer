import 'dart:convert';

import '../sources/local/key_value_store.dart';

/// Which songs have a recording **on this phone** (#124).
class AudioLibraryRepository {
  AudioLibraryRepository({required this.store});

  final KeyValueStore store;

  /// One key holding the whole map, rather than a key per song.
  static const String key = 'device.audio.v1';

  /// Every song on this phone, by song id.
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

  Future<String?> pathFor(String songId) async => (await all())[songId];

  Future<void> remember(String songId, String path) async {
    final Map<String, String> paths = await all()
      ..[songId] = path;
    await store.write(key, jsonEncode(paths));
  }

  /// Forgets the recording for a song.
  Future<void> forget(String songId) async {
    final Map<String, String> paths = await all()
      ..remove(songId);
    await store.write(key, jsonEncode(paths));
  }
}
