import 'dart:async';

import '../../domain/entities/family.dart';
import '../serialization/family_json.dart';
import 'family_repository.dart';
import '../sources/local/key_value_store.dart';

/// Reads and writes the family on the device.
///
/// This is the read path (ADR-003). It touches no network, which is not a
/// promise in a comment but a property of the code: there is nothing in this
/// class or anything it imports that could make a request. That is what makes
/// R6.1 — the rota reads with no connection — structural rather than hopeful.
class LocalFamilyRepository implements FamilyRepository {
  LocalFamilyRepository({required this._store, this._onCorruptData});

  static const String storageKey = 'family.v1';

  final KeyValueStore _store;

  /// Called when what is stored cannot be parsed.
  ///
  /// The repository cannot decide what to do about corruption — whether to
  /// report it, prompt, or stay quiet — so it hands it outward and carries on
  /// as if nothing were stored. The one thing it must not do is crash the app
  /// on open.
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
  ///
  /// Each listener gets the current value first, so a screen opening after a
  /// change does not sit empty waiting for the next one.
  ///
  /// Written as `async*` rather than by seeding the controller: the stream is
  /// broadcast, and `asBroadcastStream(onListen:)` is silently ignored when
  /// the source is already broadcast — the seed would never have fired.
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
