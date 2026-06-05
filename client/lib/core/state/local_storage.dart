import 'local_storage_stub.dart';
// Conditional imports to load the correct storage adapter depending on the runtime platform.
// This prevents cross-compilation errors (e.g. referencing 'dart:html' on mobile/desktop).
import 'local_storage_stub.dart'
    if (dart.library.html) 'local_storage_web.dart'
    if (dart.library.io) 'local_storage_io.dart'
    as platform;

/// Main entry point for local storage operations across all platforms.
/// Resolves statically to either [LocalStorageWeb] or [LocalStorageIO] at runtime.
class LocalStorage {
  static final LocalStorageImpl _impl = platform.getLocalStorage();

  /// Initialize local storage.
  static Future<void> init() => _impl.init();

  /// Retrieve the list of favorite dataset IDs.
  static List<String> getFavorites() => _impl.getFavorites();

  /// Save the list of favorite dataset IDs.
  static Future<void> saveFavorites(List<String> favorites) =>
      _impl.saveFavorites(favorites);

  /// Retrieve the list of recently viewed dataset IDs.
  static List<String> getRecents() => _impl.getRecents();

  /// Save the list of recently viewed dataset IDs.
  static Future<void> saveRecents(List<String> recents) =>
      _impl.saveRecents(recents);

  /// Retrieve the guest session status flag.
  static bool getGuestMode() => _impl.getGuestMode();

  /// Persists the guest session status flag.
  static Future<void> saveGuestMode(bool enabled) =>
      _impl.saveGuestMode(enabled);

  /// Wipes the entire local storage configuration.
  static Future<void> clearAll() => _impl.clearAll();

  /// Returns the branch name associated with the saved cache.
  static String? getLastSavedBranch() => _impl.getLastSavedBranch();

  /// Persists the active branch name to separate cache states.
  static Future<void> saveLastSavedBranch(String branch) =>
      _impl.saveLastSavedBranch(branch);

  /// Retrieve the saved locale code.
  static String getLocale() => _impl.getLocale();

  /// Save the active locale code.
  static Future<void> saveLocale(String locale) => _impl.saveLocale(locale);
}
