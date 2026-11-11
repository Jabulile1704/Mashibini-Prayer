import 'dart:async';

import '../sources/local/key_value_store.dart';

/// Which of the three the person asked for.
enum Appearance {
  /// Follow the phone. The default, and what every build before this did.
  system,
  light,
  dark,
}

/// Settings that belong to *this phone*, not to the family.
abstract interface class DeviceSettingsRepository {
  /// The member this device belongs to, or null if nobody has said.
  Future<String?> loadYouAre();

  Future<void> saveYouAre(String? memberId);

  Stream<String?> watchYouAre();

  /// Whether this phone should remind its owner before their week.
  Future<bool> loadRemindersEnabled();

  Future<void> saveRemindersEnabled({required bool enabled});

  Stream<bool> watchRemindersEnabled();

  /// Light, dark, or whatever the phone is set to.
  Future<Appearance> loadAppearance();

  Future<void> saveAppearance(Appearance appearance);

  Stream<Appearance> watchAppearance();

  Future<void> dispose();
}

class LocalDeviceSettingsRepository implements DeviceSettingsRepository {
  LocalDeviceSettingsRepository({required this.store});

  static const String youAreKey = 'device.youAre.v1';
  static const String remindersKey = 'device.reminders.v1';
  static const String appearanceKey = 'device.appearance.v1';

  final KeyValueStore store;

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast();
  final StreamController<bool> _reminderChanges =
      StreamController<bool>.broadcast();
  final StreamController<Appearance> _appearanceChanges =
      StreamController<Appearance>.broadcast();

  bool _disposed = false;

  @override
  Future<String?> loadYouAre() => store.read(youAreKey);

  @override
  Future<void> saveYouAre(String? memberId) async {
    _assertUsable();
    if (memberId == null) {
      await store.delete(youAreKey);
    } else {
      await store.write(youAreKey, memberId);
    }
    _changes.add(memberId);
  }

  @override
  Stream<String?> watchYouAre() async* {
    _assertUsable();
    yield await loadYouAre();
    yield* _changes.stream;
  }

  @override
  Future<bool> loadRemindersEnabled() async =>
      await store.read(remindersKey) == 'true';

  @override
  Future<void> saveRemindersEnabled({required bool enabled}) async {
    _assertUsable();
    await store.write(remindersKey, enabled ? 'true' : 'false');
    _reminderChanges.add(enabled);
  }

  @override
  Stream<bool> watchRemindersEnabled() async* {
    _assertUsable();
    yield await loadRemindersEnabled();
    yield* _reminderChanges.stream;
  }

  /// Reads the stored word, falling back to following the phone.
  @override
  Future<Appearance> loadAppearance() async {
    final String? stored = await store.read(appearanceKey);
    for (final Appearance appearance in Appearance.values) {
      if (appearance.name == stored) {
        return appearance;
      }
    }
    return Appearance.system;
  }

  @override
  Future<void> saveAppearance(Appearance appearance) async {
    _assertUsable();
    await store.write(appearanceKey, appearance.name);
    _appearanceChanges.add(appearance);
  }

  @override
  Stream<Appearance> watchAppearance() async* {
    _assertUsable();
    yield await loadAppearance();
    yield* _appearanceChanges.stream;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _changes.close();
    await _reminderChanges.close();
    await _appearanceChanges.close();
  }

  void _assertUsable() {
    if (_disposed) {
      throw StateError('LocalDeviceSettingsRepository used after dispose()');
    }
  }
}
