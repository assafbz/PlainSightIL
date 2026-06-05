# Lessons Learned: Save User Language Selection (Issue #100)

## 1. Cycle Executive Summary
This cycle successfully implemented and validated persistent user language selection ('en' or 'he') on both mobile/desktop and web platforms. By integrating the `LocalStorage` interface with `AppStateNotifier`'s lifecycle, the application now preserves the user's bilingual preference across restarts and sessions, eliminating layout resets and improving accessibility.

## 2. Pitfalls & Rejection Loops Analysis
- **Hurdle/Loop 1**: Test State Pollution inside the `AppStateNotifier` unit test suite.
  - **Root Cause**: Unit tests share the same mock `SharedPreferences` database instance. A change made to the locale in one test case persisted to subsequent tests. Because `AppStateNotifier` loads the locale asynchronously on creation, subsequent test cases instantiated in `setUp()` loaded the Hebrew locale instead of the default English locale, causing test assertions to fail.
  - **Resolution**: Added `SharedPreferences.setMockInitialValues({});` inside the `setUp()` function of the test suite to reset the mock database before every single test case.
  - **Prevention**: Documented this in [docs/lessons_learned.md](file:///Users/abenzaken/Dev/PlainSightIL/docs/lessons_learned.md) to ensure that any future preferences/caching tests isolate mock databases.

## 3. Documentation & Playbook Updates
No playbooks or developer setup files were modified since the existing testing guidelines already recommend hermetic setup; this case was an implementation oversight within the test suite itself.

## 4. Code Cleanup & Refactoring
- **AppStateNotifier Cleanup**: Removed duplicate and unused `import 'package:cloud_firestore/cloud_firestore.dart';` lines at the top of `app_state.dart` to resolve static analysis warnings.

## 5. Recommendations for Future Cycles
- **Isolate Storage in Tests**: Any test verifying persistent states (favorites, recents, theme modes, locale selections) must explicitly wipe the mock storage database in `setUp()` before the test subject is instantiated.
