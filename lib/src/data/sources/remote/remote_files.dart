import 'dart:io';

/// Somewhere a file can go so the other phones can see it (ADR-024).
///
/// A **spike**, and the terms are in the ADR rather than only in somebody's
/// head. The one that shapes this file:
///
/// > Nothing may depend on it. Files are stored on the device first and
/// > uploaded opportunistically. If the credit lapses, the Function is
/// > gone, or the network is absent, the app behaves exactly as it does
/// > today.
///
/// Which is why every method here returns something the caller can ignore,
/// and why **nothing throws on failure**. An upload that did not happen is
/// not an error condition; it is Tuesday. The file is already on the phone
/// — that write happened before this was called — so the worst outcome of
/// everything here failing is the behaviour the app shipped with.
///
/// This interface is deliberately about *files*, not about Azure. If the
/// spike is dropped the implementation goes and this stays, which is the
/// difference between a seam and a dependency.
abstract interface class RemoteFiles {
  /// Offers [file] to the shared store under [key].
  ///
  /// Returns true if it got there. **False is ordinary** — no network, no
  /// credit, no Function — and callers are expected to carry on.
  Future<bool> upload(File file, {required String key});

  /// Fetches [key] into [destination], if it is there and reachable.
  ///
  /// Returns null rather than throwing when it is not.
  Future<File?> download(String key, {required File destination});

  /// Whether this store is configured at all.
  ///
  /// Lets a screen say "not shared" honestly instead of showing a
  /// permanently spinning upload.
  bool get isConfigured;
}

/// The absence of a remote store, as a thing rather than a null.
///
/// **This is the default, and the app is built against it.** Every feature
/// has to work with this implementation in place — the test suite runs
/// with it, and if a test ever needs the Azure one, ADR-024's third term
/// has been broken.
///
/// A null object rather than a nullable field, because `files?.upload(...)`
/// at every call site is an invitation to forget one, and the behaviour
/// when it is missing is not "do nothing silently" — it is "the file stays
/// on this phone", which is a real answer that deserves a name.
class FilesStayOnThisPhone implements RemoteFiles {
  const FilesStayOnThisPhone();

  @override
  bool get isConfigured => false;

  @override
  Future<bool> upload(File file, {required String key}) async => false;

  @override
  Future<File?> download(String key, {required File destination}) async => null;
}
