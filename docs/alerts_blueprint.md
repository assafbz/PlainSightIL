# Implementation Blueprint: Alerting Feature (Issue #143)

## 1. File Modification Checklist

### Backend Services
- `[ ]` [firestore.rules](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/firestore.rules) - Security rules for `/subscriptions` and `/users/{userId}/alerts`.
- `[ ]` [index.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/index.ts) - Implement alert triggers on scraper completion and register helper methods.
- `[ ]` [metadata_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/metadata_scraper.ts) - Implement `areRecordsEqual` comparison and alerts for directory changes.
- `[ ]` Scrapers under `backend/functions/src/scrapers/` to return `changedCount`:
  - `[ ]` [bank_atms_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/bank_atms_scraper.ts)
  - `[ ]` [car_importers_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/car_importers_scraper.ts)
  - `[ ]` [cellular_antennas_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/cellular_antennas_scraper.ts)
  - `[ ]` [cellular_permits_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/cellular_permits_scraper.ts)
  - `[ ]` [companies_liquidation_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/companies_liquidation_scraper.ts)
  - `[ ]` [doctors_licenses_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/doctors_licenses_scraper.ts)
  - `[ ]` [local_market_bonds_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/local_market_bonds_scraper.ts)
  - `[ ]` [patent_classifications_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/patent_classifications_scraper.ts)
  - `[ ]` [travel_warnings_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/travel_warnings_scraper.ts)
  - `[ ]` [vehicle_recalls_scraper.ts](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/backend/functions/src/scrapers/vehicle_recalls_scraper.ts)

### Client Application
- `[ ]` [alert_model.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/alerts/data/models/alert_model.dart) - New alert serialization model.
- `[ ]` [alerts_notifier.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/alerts/presentation/notifiers/alerts_notifier.dart) - New Change Notifier managing streams and actions.
- `[ ]` [alerts_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/alerts/presentation/pages/alerts_page.dart) - New Alerts Feed view.
- `[ ]` [app_state.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/core/state/app_state.dart) - Integrate alerts notifier, add localization.
- `[ ]` [app_shell.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/core/widgets/app_shell.dart) - Mount alerts page, render nav bar badge.
- `[ ]` [navigation_drawer.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/core/widgets/navigation_drawer.dart) - Remove roadmap badge from alerts option, show count badge.
- `[ ]` Dataset Screens (add subscription action to appBar):
  - `[ ]` [bank_atms_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/datasets/bank_atms/pages/bank_atms_page.dart)
  - `[ ]` [car_importers_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/datasets/car_importers/pages/car_importers_page.dart)
  - `[ ]` [cellular_antennas_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/datasets/cellular_antennas/pages/cellular_antennas_page.dart)
  - `[ ]` [companies_liquidation_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/datasets/companies_liquidation/pages/companies_liquidation_page.dart)
  - `[ ]` [doctors_licenses_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/datasets/doctors_licenses/pages/doctors_licenses_page.dart)
  - `[ ]` [local_market_bonds_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/datasets/local_market_bonds/pages/local_market_bonds_page.dart)
  - `[ ]` [patent_classifications_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/datasets/patent_classifications/pages/patent_classifications_page.dart)
  - `[ ]` [travel_warnings_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/datasets/travel_warnings/pages/travel_warnings_page.dart)
  - `[ ]` [vehicle_recalls_page.dart](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/approve-prd-issue-143/client/lib/features/datasets/vehicle_recalls/pages/vehicle_recalls_page.dart)

---

## 2. Coding Tasks Checklist

### Backend Automation & Rules
- `[ ]` Verify Firestore Security Rules in `backend/firestore.rules` (ensure rules compile and restrict actions).
- `[ ]` Update all 10 record scrapers to track record writes and return `changedCount`:
  - Check existing dataset snapshots.
  - If snapshot is missing or `areRecordsEqual` returns false, record is modified/new -> increment `changedCount`.
- `[ ]` In `index.ts`, implement helper `generateAlertForSubscribers(datasetId, changedCount)`:
  - Skip if `dataset_metadata/{datasetId}` has `recordCount == 0` or is missing (first sync guard).
  - Query `/subscriptions` where `datasetId == datasetId`.
  - For each matching user, write a `new_records` document to `/users/{userId}/alerts/`.
- `[ ]` In `metadata_scraper.ts`, implement `areRecordsEqual` comparison during CKAN metadata package sync:
  - Fetch existing `datasets_metadata` documents.
  - If package is new, generate `new_government_dataset` broadcast alert. (Also `new_dataset` if `isSupported == true`).
  - If package exists and changed, check if `isSupported` transitioned from false to true -> generate `new_dataset` alert.
  - First sync guard: if `datasets_metadata` collection is empty or count is 0, skip alerts.

### Client Implementation
- `[ ]` Create `AlertModel` class matching private alerts collection properties.
- `[ ]` Create `AlertsNotifier` class:
  - Manage real-time Firestore stream subscriptions to `/users/{userId}/alerts` (paginate to 100 entries, sort `createdAt DESC`).
  - Fetch active subscriptions from `/subscriptions` where `userId == request.auth.uid`.
  - Expose actions: `toggleSubscription(datasetId)`, `markAsRead(alertId)`, `markAllAsRead()`, `deleteAlert(alertId)`.
  - Offline Mock Mode: If `AppStateNotifier.isTesting` is true, mock local list notifications and local subscriptions.
- `[ ]` Create `AlertsPage` UI:
  - Unauthenticated view: render a glassmorphic cta with a Google sign-in button.
  - Authenticated view: show a scrollable list of alerts with unread glows, mark all read button in the header, and swipe-to-dismiss support.
  - Mirror layouts for LTR/RTL (logical `Directional` classes).
- `[ ]` Integrate `AlertsNotifier` inside `AppStateNotifier` (app_state.dart) and expose its actions/properties (delegation pattern).
- `[ ]` Add bell buttons to dataset page headers.
- `[ ]` Render red badges with unread alert counts on `app_shell.dart` and `navigation_drawer.dart` navigation points.

---

## 3. Function & Module Signatures

```dart
// client/lib/features/alerts/data/models/alert_model.dart
class AlertModel {
  final String id;
  final String userId;
  final String type; // 'new_dataset', 'new_government_dataset', 'new_records'
  final Map<String, String> title; // bilingual
  final Map<String, String> description; // bilingual
  final String? datasetId;
  final int? recordCount;
  final bool isRead;
  final DateTime createdAt;

  AlertModel({ ... });
  factory AlertModel.fromMap(Map<String, dynamic> map, String id);
  Map<String, dynamic> toMap();
}

// client/lib/features/alerts/presentation/notifiers/alerts_notifier.dart
class AlertsNotifier extends ChangeNotifier {
  final bool isTesting;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  List<AlertModel> get alerts;
  List<String> get subscribedDatasetIds;
  int get unreadCount;
  bool get isLoading;

  AlertsNotifier({this.isTesting = false, this.firestore, this.auth});

  void initAlertsListener(String? userId);
  void cancelListeners();
  Future<void> toggleSubscription(String datasetId, String userId);
  Future<void> markAsRead(String alertId, String userId);
  Future<void> markAllAsRead(String userId);
  Future<void> deleteAlert(String alertId, String userId);
}
```

---

## 4. Testing & Coverage Strategy Checklist

- `[ ]` Task T1: Create rules test suite `backend/functions/test/rules.spec.ts` using `@firebase/rules-unit-testing` to verify secure read/write policies on subscriptions and alerts.
- `[ ]` Task T2: Write unit tests in `backend/functions/test/alerts.spec.ts` checking scraper completion triggers, first sync guard, and metadata transition rules.
- `[ ]` Task T3: Write client tests in `client/test/features/alerts/alerts_notifier_test.dart` to verify state logic and mock data scenarios.
- `[ ]` Task T4: Write widget tests in `client/test/features/alerts/alerts_page_test.dart` verifying glassmorphic elements, LTR/RTL layouts, and empty states.
- `[ ]` Task T5: Write E2E integration test in `e2e/alerts.spec.ts` mapping: Sign In -> Subscribe -> Scrape new record -> Receive alert -> Tap alert -> Navigate -> Mark read.

---

## 5. Documentation Checklist

- `[ ]` Task D1: Document all public alert classes, model methods, and notifier actions with Dart three-slash comments (`///`).
- `[ ]` Task D2: Document backend triggers and seeder bypass heuristics using JSDoc.

---

## 6. Compilation & Verification Targets

- Build backend: `cd backend/functions && npm run build`
- Lint backend: `cd backend/functions && npm run lint`
- Test backend: `cd backend/functions && npm test`
- Build/Get client: `cd client && flutter pub get`
- Analyze client: `cd client && flutter analyze`
- Test client: `cd client && flutter test`
