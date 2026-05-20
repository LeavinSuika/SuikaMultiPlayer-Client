import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suika_multi_player/config/constants.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden by main()');
});

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  String? get userUuid => _prefs.getString(AppConstants.storageKeyUserUuid);

  Future<void> setUserUuid(String uuid) async {
    await _prefs.setString(AppConstants.storageKeyUserUuid, uuid);
  }

  Future<void> clearUserUuid() async {
    await _prefs.remove(AppConstants.storageKeyUserUuid);
  }

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) async =>
      _prefs.setString(key, value);
  Future<void> remove(String key) async => _prefs.remove(key);
}

