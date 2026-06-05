# UI/UX Specification: Save User Language Selection (Issue #100)

## 📂 Stitch Screen References
- **Stitch Project ID**: `projects/10303868738682079846`
- **Visual Modification**: No new screens or visual UI changes are introduced in this issue. The existing language toggle button in the navigation drawer (for logged-in users) and on the login/signup pages (for guests/unauthenticated users) remains visually identical. Stitch screens are already in sync.

## 1. Visual Theme & Theme Mode
- **Theme Mode**: Unchanged. The application supports Slate Dark Mode (default) and Sleek Light Mode.
- **Visuals**: Changing the language updates the localized strings dynamically and triggers an immediate text direction shift (RTL for Hebrew, LTR for English) as defined in [docs/design.md](file:///Users/abenzaken/Dev/PlainSightIL/docs/design.md).

## 2. Component Wireframe & Layout Architecture
The language toggle component is nested within:
- `NavigationDrawer` (Client-side, lib/core/widgets/navigation_drawer.dart)
- `LoginPage` (Client-side, lib/features/auth/presentation/pages/login_page.dart)
- `SignupPage` (Client-side, lib/features/auth/presentation/pages/signup_page.dart)

No modifications are made to the visual wireframe hierarchy of these files.

## 3. Responsive Layout Guidelines
- Spacing, padding, and layout bounds remain identical to the core responsive standards defined in the codebase.

## 4. UI/UX Interface Specs
- Unchanged.

## 5. Micro-Animations & Interaction States
- **Language Switch Transition**: When the language toggle is tapped, the text and layout direction animate dynamically via the `ListenableBuilder` watching `AppStateNotifier` in `MyApp`. The transition should feel smooth without screen flicker or flashing.

## 6. UX Layout Constraints & Hurdles
- **Startup Directionality**: To prevent visual layout jumping (jitter) on application load, the saved language selection must be loaded from local storage as early as possible during the app initialization. Since SharedPreferences reads asynchronously, `AppStateNotifier` should load the setting in its constructor and notify listeners as soon as it resolves.
