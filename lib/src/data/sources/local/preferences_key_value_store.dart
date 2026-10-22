import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

/// The real store on a phone, backed by `shared_preferences`.
///
/// A family's rota is a few hundred bytes — four members, a handful of cycle
/// epochs and the odd skip — changed a few times a year. That is what a
/// key-value store is for; see ADR-006 for why this is not a database.
class PreferencesKeyValueStore implements KeyValueStore {
  PreferencesKeyValueStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}
