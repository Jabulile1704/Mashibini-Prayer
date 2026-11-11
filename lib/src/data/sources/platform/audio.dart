import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

/// Choosing a recording and playing it (#124).
abstract interface class Audio {
  /// Asks for a recording and copies it into the app's own storage.
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
    _player.onPlayerComplete.listen((void _) {
      _nowPlaying = null;
      _playing.add(null);
    });
  }

  /// Where recordings live inside the app's documents directory.
  static const String folder = 'family-audio';

  /// What the file browser will offer.
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
