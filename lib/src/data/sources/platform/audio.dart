import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

/// Choosing a recording and playing it (#124).
///
/// Behind a seam because a widget test cannot open a file browser or make a
/// noise, and because what the app does with audio is worth testing
/// separately from whether this phone can decode an MP3.
///
/// **Nothing here uploads.** The file is copied into the app's own
/// directory and its path is stored by `AudioLibraryRepository`, which
/// keeps it out of the shared family document on purpose — a path means
/// nothing on anybody else's phone.
abstract interface class Audio {
  /// Asks for a recording and copies it into the app's own storage.
  ///
  /// Returns the stored path, or null if nothing was chosen — which is an
  /// ordinary answer rather than a failure.
  Future<String?> pickFor(String songId);

  /// Starts playing [path], stopping whatever was playing before.
  Future<void> play(String path);

  Future<void> stop();

  /// What is playing, or null for silence. Emits the current value first.
  Stream<String?> playing();

  /// Forgets the file at [path]. Missing is not an error.
  Future<void> remove(String path);
}

class PlatformAudio implements Audio {
  PlatformAudio({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    // The player reaching the end of a track is the app's cue to stop
    // showing a pause button. Without this, a finished song looks like it
    // is still going.
    _player.onPlayerComplete.listen((void _) {
      _nowPlaying = null;
      _playing.add(null);
    });
  }

  /// Where recordings live inside the app's documents directory.
  static const String folder = 'family-audio';

  /// What the file browser will offer.
  ///
  /// Narrow on purpose: this is a songbook, and a picker that accepts a
  /// PDF is a picker that will one day be handed one.
  static const List<String> extensions = <String>[
    'mp3',
    'm4a',
    'aac',
    'wav',
    'flac',
  ];

  final AudioPlayer _player;
  final StreamController<String?> _playing =
      StreamController<String?>.broadcast();
  String? _nowPlaying;

  @override
  Future<String?> pickFor(String songId) async {
    final XFile? chosen = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        const XTypeGroup(label: 'Audio', extensions: extensions),
      ],
    );
    if (chosen == null) {
      return null;
    }

    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory destination = Directory('${documents.path}/$folder');
    if (!destination.existsSync()) {
      await destination.create(recursive: true);
    }

    // The song's id plus the moment, so replacing a recording writes a new
    // file rather than overwriting one the player may still be reading.
    final String extension = chosen.path.split('.').last.toLowerCase();
    final String name =
        '$songId-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final File stored = await File(chosen.path)
        .copy('${destination.path}/$name');
    return stored.path;
  }

  @override
  Future<void> play(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    _nowPlaying = path;
    _playing.add(path);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _nowPlaying = null;
    _playing.add(null);
  }

  @override
  Stream<String?> playing() async* {
    yield _nowPlaying;
    yield* _playing.stream;
  }

  @override
  Future<void> remove(String path) async {
    final File file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
