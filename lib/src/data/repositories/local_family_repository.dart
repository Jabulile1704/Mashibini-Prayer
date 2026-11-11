import 'dart:async';

import '../../domain/entities/family.dart';
import '../serialization/family_json.dart';
import 'family_repository.dart';
import '../sources/local/key_value_store.dart';

/// Reads and writes the family on the device.
class LocalFamilyRepository implements FamilyRepository {
  LocalFamilyRepository({required this._store, this._onCorruptData});

  static const String storageKey = 'family.v1';

  final KeyValueStore _store;

  /// Called when what is stored cannot be parsed.
  final void Function(Object error, StackTrace stack)? _onCorruptData;

  final StreamController<Family?> _changes =
      StreamController<Family?>.broadcast();

  bool _disposed = false;

  @override
  Future<Family?> load() async {
    final String? stored = await _store.read(storageKey);
    if (stored == null) {
      return null;
    }
    try {
      return FamilyJson.decode(stored);
    } on FormatException catch (error, stack) {
      _onCorruptData?.call(error, stack);
      return null;
    }
  }

  @override
  Future<void> save(Family family) async {
    _assertUsable();
    await _store.write(storageKey, FamilyJson.encode(family));
    _changes.add(family);
  }

  /// Emits what is stored now, then every change after it.
  @override
  Stream<Family?> watch() async* {
    _assertUsable();
    yield await load();
    yield* _changes.stream;
  }

  @override
  Future<void> clear() async {
    _assertUsable();
    await _store.delete(storageKey);
    _changes.add(null);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _changes.close();
  }

  void _assertUsable() {
    if (_disposed) {
      throw StateError('LocalFamilyRepository used after dispose()');
    }
  }
}
