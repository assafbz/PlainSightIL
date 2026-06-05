# PRD: Save User Language Selection (Issue #100)

## 1. Executive Summary & Goals
Currently, when a user selects a language (English or Hebrew) on PlainSightIL, the preference is stored only in-memory in the active `AppStateNotifier`. When the application is restarted or reloaded, the language defaults back to English.
The goal of this feature is to persist the user's language selection across sessions and application restarts. This will improve the user experience by respecting their choice and providing a seamless, personalized layout right from the initial load.

## 2. User Persona & Use Cases
- **Primary Persona**: Israeli citizens or international researchers who prefer using the application in Hebrew or English and expect their preference to be remembered.
- **Use Case 1 (Persistent Choice)**: A user changes the language to Hebrew ('HE'). They close the app and reopen it later. The app should load in Hebrew immediately without flashing or requiring another manual toggle.
- **Use Case 2 (Cross-Screen Uniformity)**: A user logs in, toggles language to Hebrew, navigates around, performs tasks, and logs out. Throughout all states, their selected language remains Hebrew.

## 3. Functional Requirements
- **FR-01 (Storage)**: The active language selection ('en' or 'he') must be persisted to the device's local storage using the `LocalStorage` facade.
- **FR-02 (Initialization)**: Upon application startup, the `AppStateNotifier` must check local storage for a saved language selection. If found, it should initialize the application with that language; otherwise, default to 'en'.
- **FR-03 (State Synchrony)**: Changing the language (via `setLocale` or `toggleLocale`) must immediately update local storage.
- **FR-04 (Multi-platform support)**: The storage mechanism must work seamlessly on both mobile/desktop (via SharedPreferences) and Web (via localStorage).

## 4. Non-Functional Requirements & UX Guidelines
- **NFR-01 (No Layout Jitter)**: The language and corresponding text direction (RTL for Hebrew, LTR for English) should load as early as possible to prevent jarring UI/layout jumps on startup.
- **NFR-02 (Robustness)**: Storage failures or missing keys must fallback gracefully to the default English ('en') locale without crashing the app.

## 5. Exclusions (Out of Scope)
- Cloud-based synchronization of language preferences across different devices (for logged-in users). Only local device persistence is within scope.
- Support for additional languages beyond English ('en') and Hebrew ('he').

## 6. Open Questions
- Should the language preference be cleared upon user logout?
  *Decision*: No, language preference is a device/app level preference, independent of authentication state. Logging out should retain the last selected language.

## 7. Product Obstacles & Scope Hurdles
- The asynchronous nature of reading from native local storage (SharedPreferences) vs the synchronous initialization of `AppStateNotifier`. We must resolve this by loading the value asynchronously and notifying listeners once available.
