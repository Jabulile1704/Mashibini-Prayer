import 'dart:io';

/// Somewhere a file can go so the other phones can see it (ADR-024).
abstract interface class RemoteFiles {
  /// Offers [file] to the shared store under [key].
  Future<bool> upload(File file, {required String key});

  /// Fetches [key] into [destination], if it is there and reachable.
  Future<File?> download(String key, {required File destination});

  /// Whether this store is configured at all.
  bool get isConfigured;
}

/// The absence of a remote store, as a thing rather than a null.
class FilesStayOnThisPhone implements RemoteFiles {
  const FilesStayOnThisPhone();

  @override
  bool get isConfigured => false;

  @override
  Future<bool> upload(File file, {required String key}) async => false;

  @override
  Future<File?> download(String key, {required File destination}) async => null;
}
