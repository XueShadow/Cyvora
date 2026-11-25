import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PreferencesStore {
  Future<String?> readString(String key);

  Future<bool> writeString(String key, String value);

  Future<int?> readInt(String key);

  Future<bool> writeInt(String key, int value);
}

class SharedPreferencesStore implements PreferencesStore {
  const SharedPreferencesStore();

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<String?> readString(String key) async =>
      (await _preferences).getString(key);

  @override
  Future<bool> writeString(String key, String value) async =>
      (await _preferences).setString(key, value);

  @override
  Future<int?> readInt(String key) async => (await _preferences).getInt(key);

  @override
  Future<bool> writeInt(String key, int value) async =>
      (await _preferences).setInt(key, value);
}
