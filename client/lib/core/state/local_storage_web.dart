// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'local_storage_stub.dart';

/// Web implementation of the [LocalStorageImpl] interface.
/// Persists data directly in the browser's [html.window.localStorage].
class LocalStorageWeb implements LocalStorageImpl {
  /// Initialization is a no-op on Web as [html.window.localStorage] is immediately accessible.
  @override
  Future<void> init() async {}

  /// Retrieves the favorite dataset IDs from localStorage, splitting the comma-separated string.
  @override
  List<String> getFavorites() {
    try {
      final value = html.window.localStorage['favorites'];
      if (value == null) return [];
      return List<String>.from(value.split(',').where((s) => s.isNotEmpty));
    } catch (_) {
      return [];
    }
  }

  /// Saves the favorite dataset IDs as a comma-separated string in localStorage.
  @override
  Future<void> saveFavorites(List<String> favorites) async {
    try {
      html.window.localStorage['favorites'] = favorites.join(',');
    } catch (_) {}
  }

  /// Retrieves the recently viewed dataset IDs from localStorage, splitting the comma-separated string.
  @override
  List<String> getRecents() {
    try {
      final value = html.window.localStorage['recents'];
      if (value == null) return [];
      return List<String>.from(value.split(',').where((s) => s.isNotEmpty));
    } catch (_) {
      return [];
    }
  }

  /// Saves the recently viewed dataset IDs as a comma-separated string in localStorage.
  @override
  Future<void> saveRecents(List<String> recents) async {
    try {
      html.window.localStorage['recents'] = recents.join(',');
    } catch (_) {}
  }

  /// Checks if the guest mode flag is set to 'true' in localStorage.
  @override
  bool getGuestMode() {
    try {
      return html.window.localStorage['guest_mode'] == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Saves the guest mode status flag in localStorage.
  @override
  Future<void> saveGuestMode(bool enabled) async {
    try {
      html.window.localStorage['guest_mode'] = enabled.toString();
    } catch (_) {}
  }

  /// Wipes all key-value pairs stored in the browser's localStorage.
  @override
  Future<void> clearAll() async {
    try {
      html.window.localStorage.clear();
    } catch (_) {}
  }

  /// Retrieves the cached git branch name from localStorage.
  @override
  String? getLastSavedBranch() {
    try {
      return html.window.localStorage['last_git_branch'];
    } catch (_) {
      return null;
    }
  }

  /// Persists the active git branch name in localStorage.
  @override
  Future<void> saveLastSavedBranch(String branch) async {
    try {
      html.window.localStorage['last_git_branch'] = branch;
    } catch (_) {}
  }
}

/// Web factory method returning a new [LocalStorageWeb] instance.
LocalStorageImpl getLocalStorage() => LocalStorageWeb();
