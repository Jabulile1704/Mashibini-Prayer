import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Getting a photograph onto this phone, and keeping it there.
///
/// Behind a seam for the usual reason — a widget test cannot open a photo
/// library — and for one specific to this: **nothing here uploads
/// anything.** ADR-010's third clause forbids file uploads and this does not
/// touch it. The picker returns a file, the file is copied into the app's own
/// directory, and a path is handed back.
///
/// That bargain has a cost, and it is the same one the journal had before
/// #104: a path is meaningless on another phone, so photographs do not sync,
/// and a reinstall takes them. The screen says so rather than letting it be
/// discovered.
abstract interface class Photos {
  /// Asks for a photograph and copies it into the app's own storage.
  ///
  /// Returns the stored path, or null if nothing was chosen. Throws only if
  /// the copy itself fails — a person declining the picker is an ordinary
  /// answer, not an error.
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
      // Resized on the way in. A modern phone photograph is several
      // megabytes and this is drawn at about 80 points across; keeping the
      // original would spend a family's storage on pixels no one can see.
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

    // The member's id plus the moment, so replacing a photograph writes a
    // new file rather than overwriting one the widget tree may still be
    // painting from a cache.
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
