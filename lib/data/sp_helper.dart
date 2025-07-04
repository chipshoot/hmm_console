import 'package:shared_preferences/shared_preferences.dart';

class SPHelper {
  static const keyName = 'name';
  static const keyPassword = 'password';

  static SharedPreferences? _preferences;

  Future setSettings(String name, String password) async {
    var result = await setString(keyName, name);
    if (!result) {
      return Future.error('Failed to save name');
    }
    result = await setString(keyPassword, password);
    if (!result) {
      return Future.error('Failed to save password');
    }
  }

  Future<Map<String?, String?>> getSettings() async {
    return {keyName: getString(keyName), keyPassword: getString(keyPassword)};
  }

  Future<SharedPreferences> getInstance() async {
    _preferences ??= await SharedPreferences.getInstance();
    return _preferences!;
  }

  Future<bool> setString(String key, String value) async {
    try {
      final prefs = await getInstance();
      return prefs.setString(key, value);
    } on Exception catch (_) {
      return false; // Handle the exception as needed
    }
  }

  String? getString(String key) {
    try {
      return _preferences?.getString(key);
    } on Exception catch (_) {
      return null; // Handle the exception as needed
    }
  }
}
