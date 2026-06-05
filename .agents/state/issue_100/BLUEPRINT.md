# Implementation Blueprint: Save User Language Selection (Issue #100)

## 1. File Modification Checklist
- `[ ]` [local_storage_stub.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/resolve-issue-hundred/client/lib/core/state/local_storage_stub.dart) - Add interface methods signatures for locale.
- `[ ]` [local_storage_io.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/resolve-issue-hundred/client/lib/core/state/local_storage_io.dart) - Implement locale persistence using SharedPreferences.
- `[ ]` [local_storage_web.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/resolve-issue-hundred/client/lib/core/state/local_storage_web.dart) - Implement locale persistence using window.localStorage.
- `[ ]` [local_storage.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/resolve-issue-hundred/client/lib/core/state/local_storage.dart) - Expose static interface wrappers for locale.
- `[ ]` [app_state.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/resolve-issue-hundred/client/lib/core/state/app_state.dart) - Add `_loadLocale()` async helper in constructor and save updates in `setLocale` / `toggleLocale`.
- `[ ]` [app_state_test.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/resolve-issue-hundred/client/test/core/state/app_state_test.dart) - Add unit tests for locale persistence.

## 2. Coding Tasks Checklist
- `[ ]` Task 1: Add `String getLocale()` and `Future<void> saveLocale(String locale)` signatures to `LocalStorageImpl` in `local_storage_stub.dart`.
- `[ ]` Task 2: Implement `getLocale()` returning `_prefs?.getString('locale') ?? 'en'` and `saveLocale()` using `_prefs?.setString('locale', locale)` in `local_storage_io.dart`.
- `[ ]` Task 3: Implement `getLocale()` returning `html.window.localStorage['locale'] ?? 'en'` and `saveLocale()` using `html.window.localStorage['locale'] = locale` in `local_storage_web.dart`.
- `[ ]` Task 4: Expose `getLocale()` and `saveLocale()` static wrapper methods in `local_storage.dart`.
- `[ ]` Task 5: Add private asynchronous method `_loadLocale()` in `AppStateNotifier` constructor that awaits `LocalStorage.init()`, reads the locale, and calls `notifyListeners()` if the locale value changes from the default `'en'`.
- `[ ]` Task 6: Call `LocalStorage.saveLocale(_locale)` inside `AppStateNotifier.setLocale` and `AppStateNotifier.toggleLocale`.

## 3. Function & Module Signatures
- `abstract class LocalStorageImpl`:
  * `String getLocale();`
  * `Future<void> saveLocale(String locale);`
- `class LocalStorage`:
  * `static String getLocale() => _impl.getLocale();`
  * `static Future<void> saveLocale(String locale) => _impl.saveLocale(locale);`
- `class AppStateNotifier`:
  * `Future<void> _loadLocale();`

## 4. Testing & Coverage Strategy Checklist
- `[ ]` Task T1: Implement unit tests in `client/test/core/state/app_state_test.dart` to verify that locale defaults to `'en'`, changes are saved, and new instances of `AppStateNotifier` read/load the saved locale correctly from SharedPreferences.
- `[ ]` Task T2: Ensure `AppStateNotifier` flow coverage for the new `_loadLocale()` logic achieves 100%.

## 5. Documentation Checklist
- `[ ]` Task D1: Document all new/modified public APIs (classes, methods, interfaces, constructors) using three-slash (`///`) comments.
- `[ ]` Task D2: Add clear inline comments explaining the async constructor initialization workaround.

## 6. Compilation & Verification Targets
- Run dependencies retrieve:
  ```bash
  flutter pub get
  ```
- Run static analysis:
  ```bash
  flutter analyze
  ```
- Run unit tests:
  ```bash
  flutter test test/core/state/app_state_test.dart
  ```

## 7. Technical Lead Blueprinting Observations
- SharedPreferences is mocked in Flutter tests using `SharedPreferences.setMockInitialValues({})` which must be initialized properly inside test suites before creating `AppStateNotifier` to prevent null errors.
