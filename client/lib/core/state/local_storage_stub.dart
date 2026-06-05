/// Interface for multi-platform local storage access.
/// Defines methods to load and save favorites, recents, and guest session states.
abstract class LocalStorageImpl {
  /// Initialize local storage services.
  Future<void> init();

  /// Retrieve the list of favorite dataset IDs.
  List<String> getFavorites();

  /// Save the list of favorite dataset IDs.
  Future<void> saveFavorites(List<String> favorites);

  /// Retrieve the list of recently viewed dataset IDs.
  List<String> getRecents();

  /// Save the list of recently viewed dataset IDs.
  Future<void> saveRecents(List<String> recents);

  /// Check if the user is in guest session mode.
  bool getGuestMode();

  /// Set the guest session mode status.
  Future<void> saveGuestMode(bool enabled);

  /// Clear all stored data values.
  Future<void> clearAll();

  /// Retrieve the last branch name used to save cache.
  String? getLastSavedBranch();

  /// Save the active branch name into local preferences.
  Future<void> saveLastSavedBranch(String branch);

  /// Retrieve the saved locale code ('en' or 'he').
  String getLocale();

  /// Save the locale code ('en' or 'he').
  Future<void> saveLocale(String locale);
}

/// Factory stub method to instantiate the platform-specific local storage implementation.
LocalStorageImpl getLocalStorage() => throw UnsupportedError(
  'Cannot create local storage without html or io libraries.',
);
