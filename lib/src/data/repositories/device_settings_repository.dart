import 'dart:async';

import '../sources/local/key_value_store.dart';

/// Settings that belong to *this phone*, not to the family.
///
/// Which member is holding the device is the only one so far, and it is
/// deliberately not part of [Family]: the family is shared data, and "who am
/// I" is different on every phone that reads it. Putting it in the shared
/// aggregate would make four devices fight over one field.
///
/// This is independent of **Q3** — whether members sign in individually or
/// share one install. Either way, a device can know which name to speak in the
/// second person.
abstract interface class DeviceSettingsRepository {
  /// The member this device belongs to, or null if nobody has said.
  Future<String?> loadYouAre();

  Future<void> saveYouAre(String? memberId);

  Stream<String?> watchYouAre();

  /// Whether this phone should remind its owner before their week.
  ///
  /// Absent means never asked, which is different from "off" only in what
  /// the app may do about it: R5.1 says an install that has never been asked
  /// sends nothing, so absent and off behave identically and the distinction
  /// is not worth storing.
  Future<bool> loadRemindersEnabled();

  Future<void> saveRemindersEnabled({required bool enabled});

  Stream<bool> watchRemindersEnabled();

  Future<void> dispose();
}

class LocalDeviceSettingsRepository implements DeviceSettingsRepository {
  LocalDeviceSettingsRepository({required this.store});

  static const String youAreKey = 'device.youAre.v1';
  static const String remindersKey = 'device.reminders.v1';

  final KeyValueStore store;

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast();
  final StreamController<bool> _reminderChanges =
      StreamController<bool>.broadcast();

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

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _changes.close();
    await _reminderChanges.close();
  }

  void _assertUsable() {
    if (_disposed) {
      throw StateError('LocalDeviceSettingsRepository used after dispose()');
    }
  }
}
