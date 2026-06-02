# E2E Test Specification: Required E2E Tests

This document defines the official **required End-to-End (E2E) tests** for the PlainSightIL platform. These tests validate the full system flow from backend emulators to the client interface.

---

## 1. Test Architecture Overview

All E2E tests are designed to execute against a local hermetic environment:
- **Backend**: Firebase Local Emulator Suite running on ports `8081` (Firestore), `4001` (Auth), and `5002` (Functions).
- **Client**: Flutter Web Client running on port `8080`.
- **Framework**: Flutter `integration_test` package combined with `flutter_driver` (configured for web chromedriver).

---

## 2. Authentication & Session Flow

### Test Case: `E2E-AUTH-01` (Guest Session Flow)
- **Objective**: Verify that users can access the application without signing in.
- **Preconditions**: User is unauthenticated (fresh launch, local storage cleared).
- **Steps**:
  1. Launch app and wait for `LoginPage` to load.
  2. Assert visible elements: "Welcome Back", "Sign in with Google", and "Continue as Guest" buttons.
  3. Tap the "Continue as Guest" button.
  4. Wait for the routing transition to complete.
- **Assertions**:
  - The application navigates to the `DashboardScreen`.
  - The mission subtitle "Democratizing Civic Data" is visible.
  - The guest session flag is set in the application state.

### Test Case: `E2E-AUTH-02` (Session Persistence)
- **Objective**: Verify that the guest session persists across app hot restarts.
- **Preconditions**: User has completed the guest flow (`E2E-AUTH-01`).
- **Steps**:
  1. Restart/Re-trigger the application launch frame.
  2. Wait for the app initialization flow.
- **Assertions**:
  - The `LoginPage` is bypassed.
  - The application loads directly onto the `DashboardScreen`.

---

## 3. Bilingual & RTL Directionality

### Test Case: `E2E-LOC-01` (Language Switcher & UI Mirroring)
- **Objective**: Verify that switching language context modifies text directionality and translates key labels.
- **Preconditions**: App is loaded on `DashboardScreen` in English (LTR).
- **Steps**:
  1. Locate the language switch toggle button (key displays `HE`).
  2. Verify that the parent container direction is `TextDirection.ltr`.
  3. Tap the `HE` toggle button.
  4. Wait for the rebuild to settle.
  5. Verify translation of dashboard labels (e.g. "Cellular Antennas" translates to "אנטנות סלולריות").
  6. Tap the menu drawer icon (now on the right side).
  7. Locate and tap the drawer language toggle button (displays `EN`).
- **Assertions**:
  - When Hebrew is active, the top-level `Directionality` widget reports `TextDirection.rtl`.
  - Layout structures (menus, lists, icons) mirror horizontally.
  - Text translations update immediately without page reload.
  - Tapping the drawer toggle successfully switches the locale back to English (LTR).

---

## 4. Cellular Antennas Map Visualizer

### Test Case: `E2E-ANT-01` (Map Clustering & Details Flow)
- **Objective**: Verify that map markers populate, cluster, and display detailed information on tap.
- **Preconditions**: Firestore emulator contains seeded cellular antenna records under `cellular_antennas`.
- **Steps**:
  1. From the `DashboardScreen`, tap the "Cellular Antennas" card.
  2. Wait for the Map View to load.
  3. Locate the `MarkerClusterLayerWidget`.
  4. Perform a tap on a marker cluster circle.
  5. Tap on a single antenna marker pin.
- **Assertions**:
  - Map markers are painted on the screen.
  - Tapping a cluster zooms in and resolves the cluster into individual markers.
  - Tapping an antenna marker opens the bottom sheet containing details (Antenna ID, License Number, Status, Operator).

### Test Case: `E2E-ANT-02` (Layer Selection & Filtering)
- **Objective**: Verify toggling between Active Antennas and Construction Permits.
- **Preconditions**: App is on the `TowersScreen` map view.
- **Steps**:
  1. Locate the tab controller or segment filter.
  2. Tap the "Construction Permits" segment option.
  3. Verify map updates with construction permit markers.
  4. Tap the "Active Towers" segment option.
- **Assertions**:
  - Toggling segments dynamically switches the data source array passed to the map controller.
  - Markers refresh to show correct geo-pins corresponding to the selected layer.

### Test Case: `E2E-ANT-03` (GPS Recenter and Fallback)
- **Objective**: Verify map recenter behavior under permitted and denied location states.
- **Preconditions**: User is on `TowersScreen` map view.
- **Steps**:
  1. Tap the "Recenter on Location" floating action button.
  2. Assert the location explanation dialog appears.
  3. Tap "Cancel" to simulate user denial.
  4. Tap "Recenter on Location" again.
  5. Tap "Allow" to simulate user permission.
- **Assertions**:
  - Tapping "Cancel" closes the dialog and displays a SnackBar warning: "Could not access current location. Centering on Tel Aviv."
  - Tapping "Allow" requests location. If the platform mock throws an error, the map centers on Tel Aviv fallback coordinates.

---

## 5. Companies in Liquidation Directory

### Test Case: `E2E-LIQ-01` (Search & Hebrew Query Filtering)
- **Objective**: Verify searching and filtering companies in liquidation.
- **Preconditions**: Firestore emulator is seeded with companies records.
- **Steps**:
  1. Navigate to the Directory tab and open the "Companies in Liquidation" visualizer.
  2. Tap the search input bar.
  3. Type a Hebrew company name query (e.g. "חברה").
  4. Wait for search query debounce timer.
- **Assertions**:
  - The list filters down to show only company cards containing the search string in their title.
  - If no matches occur, an empty state widget is rendered with a "Clear Search" button.

### Test Case: `E2E-LIQ-02` (Endless Scrolling / Lazy Load)
- **Objective**: Verify pagination of list records.
- **Preconditions**: Liquidations collection contains > 50 records.
- **Steps**:
  1. Scroll the company ListView downward to the bottom edge.
  2. Wait for scroll threshold to trigger more data loading.
- **Assertions**:
  - A loading spinner briefly displays at the list footer.
  - Extra items append to the list, expanding list length beyond the initial limit.

---

## 6. Offline Support & Caching

### Test Case: `E2E-OFF-01` (Offline Navigation & Local Cache Access)
- **Objective**: Verify that previously loaded dataset data is available offline from local cache.
- **Preconditions**: App has previously loaded the Liquidation directory while online.
- **Steps**:
  1. Terminate internet connection simulation in the client context (or disconnect backend emulator connection).
  2. Navigate away from the Directory, then return.
  3. Scroll the cached list.
- **Assertions**:
  - An offline warning banner is displayed at the top/bottom of the page.
  - The previously loaded data remains fully populated and readable from the local Firestore persistence cache and memory buffers.
  - The application does not crash or show a black screen.
