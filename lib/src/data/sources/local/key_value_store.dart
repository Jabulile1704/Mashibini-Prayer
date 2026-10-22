/// A place to put a string and get it back.
///
/// Deliberately the smallest interface that persistence needs. The repository
/// depends on this rather than on a package, so the tests use an in-memory
/// implementation and never load a platform plugin — which is also why the
/// domain's behaviour can be proven without a device (N2).
abstract interface class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}
