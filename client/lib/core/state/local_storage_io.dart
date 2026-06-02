import 'package:shared_preferences/shared_preferences.dart';
import 'local_storage_stub.dart';

/// Native (Android, iOS, macOS, Windows, Linux) implementation of [LocalStorageImpl].
/// Persists data locally on device storage using the [SharedPreferences] plugin.
class LocalStorageIO implements LocalStorageImpl {
  SharedPreferences? _prefs;

  /// Loads and binds the underlying [SharedPreferences] instance.
  @override
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  /// Retrieves the list of favorite dataset IDs using the shared preferences key 'favorites'.
  @override
  List<String> getFavorites() {
    return _prefs?.getStringList('favorites') ?? [];
  }

  /// Saves the list of favorite dataset IDs under the shared preferences key 'favorites'.
  @override
  Future<void> saveFavorites(List<String> favorites) async {
    await _prefs?.setStringList('favorites', favorites);
  }

  /// Retrieves the list of recently viewed dataset IDs using the key 'recents'.
  @override
  List<String> getRecents() {
    return _prefs?.getStringList('recents') ?? [];
  }

  /// Saves the list of recently viewed dataset IDs under the key 'recents'.
  @override
  Future<void> saveRecents(List<String> recents) async {
    await _prefs?.setStringList('recents', recents);
  }

  /// Retrieves the guest mode session status flag from shared preferences.
  @override
  bool getGuestMode() {
    return _prefs?.getBool('guest_mode') ?? false;
  }

  /// Persists the guest mode session status flag under the key 'guest_mode'.
  @override
  Future<void> saveGuestMode(bool enabled) async {
    await _prefs?.setBool('guest_mode', enabled);
  }

  /// Wipes all key-value pairs stored in the platform's SharedPreferences.
  @override
  Future<void> clearAll() async {
    await _prefs?.clear();
  }

  /// Retrieves the cached git branch name from SharedPreferences.
  @override
  String? getLastSavedBranch() {
    return _prefs?.getString('last_git_branch');
  }

  /// Persists the active git branch name in SharedPreferences.
  @override
  Future<void> saveLastSavedBranch(String branch) async {
    await _prefs?.setString('last_git_branch', branch);
  }
}

/// Native factory method returning a new [LocalStorageIO] instance.
LocalStorageImpl getLocalStorage() => LocalStorageIO();
