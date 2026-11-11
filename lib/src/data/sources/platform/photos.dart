import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Getting a photograph onto this phone, and keeping it there.
abstract interface class Photos {
  /// Asks for a photograph and copies it into the app's own storage.
  Future<String?> pickFor(String memberId);

  /// Forgets a stored photograph. Missing is not an error.
  Future<void> remove(String path);
}

class PlatformPhotos implements Photos {
  const PlatformPhotos();

  /// Where the copies live, inside the app's documents directory.
  static const String folder = 'family-photos';

  @override
  Future<String?> pickFor(String memberId) async {
    final XFile? chosen = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
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
        '$memberId-${DateTime.now().millisecondsSinceEpoch}.$extension';
    final File stored = await File(chosen.path)
        .copy('${destination.path}/$name');
    return stored.path;
  }

  @override
  Future<void> remove(String path) async {
    final File file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
