import 'dart:async';

import 'package:mashibini_prayer/src/data/sources/platform/audio.dart';

/// Audio without a file browser or a speaker.
///
/// [next] is what the picker "returns" — null for somebody who opened it
/// and changed their mind, which is an ordinary answer and the case most
/// worth testing.
class FakeAudio implements Audio {
  FakeAudio({this.next, this.throws});

  String? next;
  Object? throws;

  final List<String> pickedFor = <String>[];
  final List<String> played = <String>[];
  final List<String> removed = <String>[];
  int stops = 0;

  String? _nowPlaying;
  final StreamController<String?> _playing =
      StreamController<String?>.broadcast();

  @override
  Future<String?> pickFor(String songId) async {
    pickedFor.add(songId);
    final Object? error = throws;
    if (error != null) {
      throw error;
    }
    return next;
  }

  @override
  Future<void> play(String path) async {
    played.add(path);
    _nowPlaying = path;
    _playing.add(path);
  }

  @override
  Future<void> stop() async {
    stops++;
    _nowPlaying = null;
    _playing.add(null);
  }

  @override
  Stream<String?> playing() async* {
    yield _nowPlaying;
    yield* _playing.stream;
  }

  @override
  Future<void> remove(String path) async => removed.add(path);

  /// What the real player does when a track reaches its end.
  void finish() {
    _nowPlaying = null;
    _playing.add(null);
  }
}
