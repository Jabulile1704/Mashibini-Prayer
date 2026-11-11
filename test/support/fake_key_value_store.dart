import 'package:mashibini_prayer/src/data/sources/local/key_value_store.dart';

/// An in-memory [KeyValueStore] for tests.
class FakeKeyValueStore implements KeyValueStore {
  FakeKeyValueStore([Map<String, String>? initial])
    : values = <String, String>{...?initial};

  final Map<String, String> values;

  int readCount = 0;
  int writeCount = 0;
  int deleteCount = 0;

  /// When set, [read] throws this instead of returning.
  Object? failOnRead;

  @override
  Future<String?> read(String key) async {
    readCount++;
    final Object? failure = failOnRead;
    if (failure != null) {
      throw failure;
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    values.remove(key);
  }
}
