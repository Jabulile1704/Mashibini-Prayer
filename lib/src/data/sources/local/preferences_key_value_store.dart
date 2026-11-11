import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

/// The real store on a phone, backed by `shared_preferences`.
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
