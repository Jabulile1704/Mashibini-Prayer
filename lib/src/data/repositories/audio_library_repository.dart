import 'dart:convert';

import '../sources/local/key_value_store.dart';

/// Which songs have a recording **on this phone** (#124).
///
/// Deliberately **not** on `Family`, and that is the whole design decision
/// in this file.
///
/// The songbook itself is shared: a title, who sings it, who chose it. That
/// rides the family document and merges across phones (ADR-008). A *file
/// path* cannot: `/var/mobile/.../a-song.mp3` means nothing on anybody
/// else's device, and syncing it would show the family a play button that
/// does nothing — which is worse than showing no button at all.
///
/// `Member.photoPath` made the opposite choice on Day 23 and put the path
/// in the shared document. That was a mistake of the same shape, and #75
/// will have to strip those on the way in. This one is kept out from the
/// start.
///
/// So: the song is shared, the recording is local, and the join happens on
/// the screen. A phone that has the file can play it; a phone that has not
/// is told the recording is on somebody else's phone, which is true.
class AudioLibraryRepository {
  AudioLibraryRepository({required this.store});

  final KeyValueStore store;

  /// One key holding the whole map, rather than a key per song.
  ///
  /// The map is tiny — one short path per song — and reading it is what
  /// every screen does first. A key per song would mean a read per song to
  /// draw one list.
  static const String key = 'device.audio.v1';

  /// Every song on this phone, by song id.
  Future<Map<String, String>> all() async {
    final String? stored = await store.read(key);
    if (stored == null || stored.isEmpty) {
      return <String, String>{};
    }
    final Object? decoded = jsonDecode(stored);
    if (decoded is! Map<String, Object?>) {
      // A corrupt map is not worth losing the songbook over: the recordings
      // are a convenience and the titles are the record.
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
  ///
  /// Does not delete the file — that is the caller's to do if it wants,
  /// and keeping the two separate means forgetting a mapping can never
  /// take somebody's audio with it by surprise.
  Future<void> forget(String songId) async {
    final Map<String, String> paths = await all()
      ..remove(songId);
    await store.write(key, jsonEncode(paths));
  }
}
