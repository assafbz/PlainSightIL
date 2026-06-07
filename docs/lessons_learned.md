# Lessons Learned: Cellular Permits Integration Pitfalls & Solutions

This document outlines key technical challenges, pitfalls, and solutions encountered during the integration of the **Cellular Antennas Under Construction** dataset. Future developers should reference these guidelines to avoid similar issues.

---

## 1. Pitfall: Web-Interop Casting TypeError (`FirebaseException`)

### Symptoms
When running the Flutter client app locally in Chrome (`flutter run -d chrome`), the app crashed on load with a red screen displaying:
`TypeError: Instance of 'FirebaseException': type 'FirebaseException' is not a subtype of type 'JavaScriptObject'`

### Root Cause
- The app accessed `FirebaseFirestore.instance` inside the app state notifier's initialization without calling `Firebase.initializeApp()` in `main()`.
- Because widget tests bypassed real Firestore calls using a mock state flag (`AppStateNotifier.isTesting = true`), this initialization gap was masked during automated test execution.

### Corrective Action & Best Practice
Always initialize Firebase in the client app entrypoint (`lib/main.dart`) when running on real devices or web targets:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: 'demo-app-id',
        messagingSenderId: 'demo-sender-id',
        projectId: 'demo-plainsightil',
      ),
    );
    // Connect to local Firestore emulator
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8081);
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
  runApp(const MyApp());
}
```

---

## 2. Pitfall: `admin.firestore.GeoPoint` Runtime Exception in Emulator

### Symptoms
During scraper manual synchronization checks, Cloud Function invocations failed with the error:
`TypeError: admin.firestore.GeoPoint is not a constructor`

### Root Cause
In Node.js / TypeScript Firebase Functions, importing `firebase-admin` via `import * as admin from 'firebase-admin'` and accessing `admin.firestore` does not guarantee static constructors (like `GeoPoint` or `FieldValue`) are bound in every module resolution or bundler environment.

### Corrective Action & Best Practice
Import Firestore helper classes directly from the sub-module rather than the main namespace:
```typescript
// Avoid:
import * as admin from "firebase-admin";
const point = new admin.firestore.GeoPoint(lat, lng);

// Recommended:
import { GeoPoint } from "firebase-admin/firestore";
const point = new GeoPoint(lat, lng);
```

---

## 3. Pitfall: Emulator Port Conflicts (Port 8080 Taken)

### Symptoms
Running `firebase emulators:start` failed immediately with:
`Could not start Firestore Emulator, port taken.`

### Root Cause
By default, the Firestore Emulator attempts to bind to port `8080`. If another workspace or process (e.g. Java from another project) is listening on `8080`, the emulator suite fails to start.

### Corrective Action & Best Practice
1. **Explicit Mappings:** Define unique port mappings for each project in `firebase.json`:
   ```json
   "emulators": {
     "firestore": { "port": 8081 },
     "functions": { "port": 5002 },
     "ui": { "enabled": true, "port": 4001 }
   }
   ```
2. **Process Cleanup:** Locate and kill orphaned Java emulator instances:
   ```bash
   lsof -i :8081
   kill -9 <PID>
   ```

---

## 4. Pitfall: SDLC Git Hook Rejections (Branch Naming & Linter Rules)

### Symptoms
- Commits were blocked with: `🛑 ERROR: Branch name 'feature/cellular-permits-integration' does not follow SDLC conventions!`
- Git pushes were blocked with: `🛑 ERROR: Flutter analysis failed. Please fix all lint warnings and errors.` due to double quotes in string literals.

### Root Cause
Strict workspace validation is enforced by hooks to keep code quality high. Branch names must comply with the regex `(agents|dev)/<issue_id>-<description>`. Coding conventions require single quotes for Dart strings where applicable.

### Corrective Action & Best Practice
- **Branch Naming:** Name feature branches with compliant prefixes:
  `git checkout -b agents/102-cellular-permits-integration`
- **Pre-Push Validation:** Run formatter and linter checks locally before trying to push:
  ```bash
  dart format .
  flutter analyze
  ```

---

## 5. Pitfall: Coordinate Mapping & Custom Painter Visual Testing Gaps

### Symptoms
- The Map/Radar visualizer displayed incorrect, randomized coordinate pins for the cellular permits dataset, and completely omitted pins for the active antennas dataset.
- Real coordinate projections were not bound to the UI visualizer, causing mismatch between lists and map visualizations.

### Root Cause
- High-fidelity visual components (like `RadarGridPainter` using `CustomPainter`) relied on static mock/seeded-random data generators for simplicity in early design stages.
- The integration tests and state mocks did not initially define a unified data contract for geospatial coordinates (such as a standard `'coordinates'` key with a `GeoPoint` value) across all dataset items, causing coordinates to be missing or mismatched.
- Lack of default fallback scaling logic in the custom painter would cause divisions by zero or visual overflows if no valid coordinate pins were present or if all pins shared the exact same coordinates.

### Corrective Action & Best Practice
- **Production Data Contract Alignment:** Ensure mock/testing datasets contain all keys and types present in real production Firestore documents (e.g. `GeoPoint` coordinates).
- **Graceful Visual Fallbacks:** Custom canvas painters must implement robust protection against empty states, zero-delta inputs, and missing keys.
- **Dynamic Projection Scaling:** Map geographic latitude/longitude values relative to the average lat/lng of the dataset, scaling by max-radius limits so coordinate pins always fit within visual boundaries regardless of the geographic region:
  ```dart
  final double scale = maxDelta > 0 ? (maxRadius * 0.8) / maxDelta : 0.0;
  final double px = delta.dx * scale;
  final double py = -delta.dy * scale; // Flip Y for screen space
  ```
## 6. Pitfall: Scraper Emulator Throttling vs Manual Synchronizations

### Symptoms
During local emulation development, manual synchronization triggers (via the Admin UI) only retrieved a small subset (e.g., 10 records) of the dataset instead of pulling the full data.

### Root Cause
Scrapers checked the global `process.env.FUNCTIONS_EMULATOR === 'true'` flag and unconditionally capped their records to keep startup seeding lightweight, failing to distinguish between automated background startup triggers and active manual sync requests.

### Corrective Action & Best Practice
1. Refactor all scraper modules to accept an optional configuration options object:
   ```typescript
   export async function scrapeAndSyncDataset(
     db: admin.firestore.Firestore,
     options?: { limit?: number; forceFullSync?: boolean }
   )
   ```
2. Leverage the HTTP request method inside cloud functions: trigger a quick seeded GET request on startup, but pass `forceFullSync: true` on POST requests initiated by the Admin panel.

---

## 7. Pitfall: Massive Wasted Firestore Writes on Unchanged Scraper Records

### Symptoms
Every scraper execution unconditionally wrote all records (e.g., 3,019 ATMs) to Cloud Firestore, resulting in high resource consumption, high write costs, and constant timestamp churn.

### Root Cause
The scrapers used batch write commands directly on all incoming records without checking if the records had actually changed since the last execution.

### Corrective Action & Best Practice
1. Fetch existing documents in chunks (using `db.getAll(...docRefs)`) prior to saving.
2. Implement a recursive equality utility (`areRecordsEqual`) that ignores transient metadata attributes (like `createdAt` or `updatedAt`) to check for changes.
3. Skip the document write if the records are identical, preserving `lastUpdated` timestamps and preventing duplicate writes.

---

## 8. Pitfall: Node Globals and Quotes in Flat ESLint Configurations

### Symptoms
Static checks and linter gates failed with `process is not defined`, `Buffer is not defined`, or quotes errors on Hebrew strings containing double quotes (e.g., `בע"מ`).

### Root Cause
Flat ESLint configs (`eslint.config.js`) do not implicitly inherit Node.js global variables, and strict quote linting rules block single quotes unless escape parameters are defined.

### Corrective Action & Best Practice
1. Explicitly define environment globals in `eslint.config.js`:
   ```javascript
   languageOptions: {
     globals: {
       process: "readonly",
       Buffer: "readonly",
     }
   }
   ```
2. Configure the `quotes` rule with the `avoidEscape` option so strings containing internal double quotes can be cleanly wrapped in single quotes without triggering lint failures:
   ```javascript
   rules: {
     "quotes": ["error", "double", { "avoidEscape": true }]
   }
   ```

---

## 9. Pitfall: Dynamic Timestamps Drift in Change-Detection Tests

### Symptoms
Unit tests asserting `areRecordsEqual` write-skips failed with:
`AssertionError: expected "vi.fn()" to not be called at all, but actually been called 1 times`

### Root Cause
The mock raw records used in the test case lacked date fields. Consequently, the scraper generated them dynamically during parsing using `new Date().toISOString()`. Because the parsing within the test setup and the scraper execution happened a few milliseconds apart, the generated timestamps differed slightly. `areRecordsEqual` detected this difference and triggered a write instead of skipping it.

### Corrective Action & Best Practice
Always specify static timestamps (e.g., `"תאריך הגשת הבקשה": "2024-05-12T00:00:00"`) in mock raw records for tests verifying change-detection and skip-write logic.

---

## 10. Pitfall: Registry Type Incompatibilities for Scrapers

### Symptoms
Modifying the cellular permits scraper function signature to accept option parameters (e.g., `options?: { forceFullSync?: boolean }`) broke functions compilation at the registration point (`scraperRegistry` in `index.ts`) because other scrapers in the registry did not accept the same parameter options.

### Root Cause
TypeScript's strict index signature matching on `Record<string, ScraperFunction>` does not allow polymorphic function signatures if defined too rigidly.

### Corrective Action & Best Practice
Define the index registry signature using rest parameters or loose parameters (e.g., `(...args: any[]) => Promise<{ count: number }>`) and perform type casting/assertion inside the individual routes/wrappers.

---

## 11. Pitfall: Emulator Socket Hang-ups & Zombie Processes

### Symptoms
Local emulator functions triggered timed out after 60s with `Error: socket hang up` or `Pub/Sub Emulator fatal error: stopping all emulators`.

### Root Cause
Node processes started with `detached: true` in the workspace runner became zombie/orphaned processes when their parent CLI runner was stopped. These lingering processes kept bindings on the emulator ports and sockets, leading to severe resource conflicts.

### Corrective Action & Best Practice
Enforce clean termination of all java/node background processes using `pkill` / `killall` before restarting the emulator environment.

---

## 12. Pitfall: Deep Comparison Type Mismatches in Equality Utility

### Symptoms
Documents containing empty arrays or objects are incorrectly evaluated as identical to documents containing empty objects/arrays, bypassing necessary writes.

### Root Cause
The record comparison utility checked `Array.isArray(existing)` but did not enforce that `incoming` must also be an array before looping or returning true.

### Corrective Action & Best Practice
When doing type-specific deep comparisons, always check that both existing and incoming values share the same structure/type:
```typescript
if (Array.isArray(existing) || Array.isArray(incoming)) {
  if (!Array.isArray(existing) || !Array.isArray(incoming)) return false;
  // proceed with array comparison...
}
```

---

## 13. Pitfall: Inconsistent Dataset Titles & Backend Overwrites

### Symptoms
The Companies Liquidation dataset was displayed with an incorrect title ("מאגר הכונס הרשמי") on the Dataset Directory and Admin Dashboard cards, while its corresponding visualizer screen displayed "חברות בפירוק".

### Root Cause
1. In Node.js / TypeScript backend Cloud Functions, the metadata scraper (`metadata_scraper.ts`) queried the open data portal CKAN package search API and retrieved the default package title `"מאגר הכונס הרשמי"`.
2. This title was saved into Firestore metadata under the `title` field, overriding the user-friendly title `"חברות בפירוק"`.
3. Client mock data and tests hardcoded the incorrect title, creating a testing dependency on the wrong name.

### Corrective Action & Best Practice
Implement dynamic overrides in the metadata scraper when mapping CKAN package search results to Firestore documents:
```typescript
      let title = pkg.title.trim();
      if (id === DATASET_IDS.COMPANIES_LIQUIDATION) {
        title = "חברות בפירוק";
      }
```
Ensure all mock data, widget tests, and E2E element locators are structurally synchronized to expect the clean user-friendly dataset title.

---

## 14. Pitfall: Bypassing/Skipping SDLC Gates (Process Quality Compliance)

### Symptoms
- Changes are pushed, merged, or deployed without all intermediate SDLC gates (Discovery, Design, Tech Design, Security, Blueprinting, Implementation, QA Validation, Lessons Learned) having their state files and deliverables properly completed, leading to undocumented changes, untracked requirements, or missed integration testing.

### Root Cause
- Fast-tracking fixes or feature implementations directly to code modifications while ignoring the active phase tracking inside `.agents/state/active_issues/`.
- Rushing transitions without verifying formatting and lint compliance beforehand, leading to late-stage Quality Gate transition blocks.

### Corrective Action & Best Practice
- **Unconditional Process Compliance:** The SDLC process flow must always be strictly followed from start to finish. Deliverables (`PRD.md`, `DESIGN.md`, `TDD.md`, `SECURITY.md`, `BLUEPRINT.md`, `QA_REPORT.md`, `LESSONS_LEARNED.md`) must be generated in the issue's state directory.
- **Investigate and Rectify Failures:** If a step in the SDLC is bypassed, blocked, or fails, developers (both human and AI agents) must immediately investigate the root cause (e.g., conflicting linter settings, missing requirements, or port blockages) and apply the correct fixes, rather than bypassing quality gates.

---

## 15. Pitfall: Child Process Spawning Deprecation Warnings (`[DEP0190]`) on Non-Windows Hosts

### Symptoms
When starting up local dev servers or running test scripts on macOS or Linux, logs are cluttered with the warning:
`(node:XXXXX) [DEP0190] DeprecationWarning: Passing args to a child process with shell option true can lead to security vulnerabilities...`

### Root Cause
Spawning CLI processes (like `npm`, `npx`, or `flutter`) with `shell: true` is only required on Windows systems (where these commands map to `.cmd` or `.bat` wrapper files). On macOS and Linux, executing them with `shell: true` triggers Node deprecation warnings and can disrupt process termination hierarchy.

### Corrective Action & Best Practice
Use conditional shell activation based on the platform name:
```javascript
const child = spawn('npm', ['run', 'build'], {
  cwd: targetDir,
  shell: process.platform === 'win32'
});
```

---

## 16. Pitfall: GCP Metadata Server Lookup Warnings in Local Dev (`MetadataLookupWarning`)

### Symptoms
During startup or emulator execution, logs show repeating stacks of GCP warnings:
`[Backend-Err] (node:XXXX) MetadataLookupWarning: received unexpected error = All promises were rejected code = UNKNOWN`

### Root Cause
Google Cloud Client Libraries (such as `google-auth-library` or GCP Pub/Sub wrappers) attempt to query the internal Google metadata server to verify GCE environment properties. Locally, these requests time out and produce long logs.

### Corrective Action & Best Practice
Set the `METADATA_SERVER_DETECTION` environment variable to `'none'` when launching node/emulator child processes locally:
```javascript
const emulator = spawn('npx', ['firebase-tools', 'emulators:start'], {
  env: {
    ...process.env,
    METADATA_SERVER_DETECTION: 'none'
  }
});
```

---

## 17. Pitfall: Strict Version Checking for Node Engines in Firebase CLI

### Symptoms
Setting the `engines.node` block in the functions `package.json` to comparison range values (such as `">=22"`) results in a crash during emulator load:
`Failed to load function definition from source: FirebaseError: Detected node engine >=22 in package.json, which is not a supported version. Valid versions are 20, 22, 24`

### Root Cause
The Firebase CLI parser does not support semver range operators for local Node engine checks and expects exact engine string keys like `"20"`, `"22"`, or `"24"`.

### Corrective Action & Best Practice
Keep the engines configuration set to the target deploy version (e.g. `"22"`), and suppress mismatch warnings locally by setting the `--no-deprecation` Node flag. Always ensure the Node engines version matches one of the exact supported runtimes (e.g., 20, 22, or 24) rather than a semver range:
```javascript
const child = spawn('npx', ['firebase-tools', ...], {
  env: {
    ...process.env,
    NODE_OPTIONS: '--no-deprecation'
  }
});
```

---

## 18. Pitfall: SharedPreferences Test State Pollution

### Symptoms
AppStateNotifier unit tests fail with unexpected locale states (e.g., expecting `'en'` but getting `'he'`), or other settings tests fail in a timing-dependent or execution-order-dependent manner.

### Root Cause
`SharedPreferences` in Flutter testing preserves state across different `test()` blocks within the same file unless it is cleared/mock initial values are reset. Notifiers that perform asynchronous loading on startup will read values written by previous tests, corrupting the test environment.

### Corrective Action & Best Practice
Always reset mock initial values in the `setUp` function of the test suite before creating the test subject:
```dart
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppStateNotifier.isTesting = false;
      appState = AppStateNotifier();
    });
```
This guarantees that each test starts with a clean, isolated database.

---

## 19. Pitfall: Missing Telemetry & Manual Sync Mapping for New Datasets

### Symptoms
When attempting to trigger a manual sync for a newly integrated dataset from the Admin Dashboard, the operation fails at runtime with an `Unknown dataset ID` exception.

### Root Cause
The `triggerManualSync` method in `TelemetryNotifier` maps dataset IDs to their respective Cloud Function triggers. If a new dataset is added, but its ID mapping is omitted in `TelemetryNotifier`, the method falls through to the default exception branch. Furthermore, missing entries in admin metadata and directory records mock data setups can cause null-reference issues.

### Corrective Action & Best Practice
When integrating a new dataset, always ensure the dataset ID constant is registered in the client-side telemetry notifier (`telemetry_notifier.dart`) and mapped to the corresponding Cloud Function trigger in `triggerManualSync`. Additionally, register the dataset in the admin metadata mock data listener (`initAdminMetadataListener`) and directory listener (`initDirectoryListener`) to prevent null reference issues during local testing/mock execution.

---

## 20. Pitfall: Reactive Notifier State Read Outside of ListenableBuilder Builder Callback

### Symptoms
A dataset visualizer screen (or list page) displays blank states or does not dynamically update when new records are loaded, even though the state notifier successfully retrieves and stores the records.

### Root Cause
If reactive notifier fields (such as `appState.bondRecords`) are assigned to local variables outside the builder callback of a `ListenableBuilder` (e.g., in the outer build method block), Flutter does not register a dependency on that notifier for that specific data. When the notifier calls `notifyListeners()`, the widget does not rebuild with the fresh data.

### Corrective Action & Best Practice
Always access and read reactive state attributes *inside* the builder callback of a `ListenableBuilder` or other reactive widget:
```dart
// Avoid:
final list = widget.appState.bondRecords;
return ListenableBuilder(
  listenable: widget.appState,
  builder: (context, _) {
    return ListView.builder(itemCount: list.length, ...);
  },
);

// Recommended:
return ListenableBuilder(
  listenable: widget.appState,
  builder: (context, _) {
    final list = widget.appState.bondRecords;
    return ListView.builder(itemCount: list.length, ...);
  },
);
```

---

## 21. Pitfall: Asynchronous Timing and Mock Delays in Widget/Unit Testing

### Symptoms
Unit or widget tests fail on state assertions (e.g. expecting loading indicators to dismiss or records to display), but the same code works fine when running manually.

### Root Cause
Test assertions run synchronously and may execute before asynchronous mock databases or async state notifier updates (which use delayed futures or microtasks) resolve. For instance, if a mock notifier has a 50ms simulation delay, a widget test asserting immediately will read the state *before* the delay completes.

### Corrective Action & Best Practice
In unit tests, use `Future.delayed` or advance clocks using fake async zones. In widget tests, use explicit timer advances to allow the async operations to settle:
```dart
// Allow mock asynchronous operations to resolve
await tester.pump(const Duration(milliseconds: 100));
```

---

## 22. Pitfall: Invalid Typography Reference in Design System Integration

### Symptoms
Compilation fails on a newly introduced UI screen with an error stating that a typography member does not exist (e.g., `AppTypography.bodyMd`).

### Root Cause
Using typography or styling tokens that are not registered in the shared design system (`AppTypography` or `AppColors`).

### Corrective Action & Best Practice
Ensure all UI layouts use exactly the active typography tokens defined in the design system (e.g., `AppTypography.bodySm` or `AppTypography.bodyLg`). Do not assume standard sizing names (like `bodyMd`) exist unless verified in the styling tokens declaration.

---

## 23. Pitfall: Concurrent Dataset Integration Merge Conflicts

### Symptoms
PR merge is blocked by GitHub reporting merge conflicts. Multiple rounds of local conflict resolution are needed as new PRs continue to merge into `main` during CI wait windows.

### Root Cause
Multiple dataset integrations (e.g., Vehicle Recalls #128, Car Importers #125, Local Market Bonds #126) run in parallel across separate worktrees, all modifying the same shared registration files: `index.ts`, `constants.ts`, `firestore.rules`, `app_state.dart`, `dashboard_page.dart`, `directory_page.dart`, `mock_data.dart`, `dataset_ids.dart`, `admin_page.dart`, `telemetry_notifier.dart`, and `notifiers_unit_test.dart`. Each integration adds entries to the same lists, enums, and registration points.

### Corrective Action & Best Practice
1. **Budget for conflict resolution**: When multiple integrations run concurrently, expect 2-3 rounds of merge conflict resolution per PR and factor this into cycle time estimates.
2. **Merge quickly after CI passes**: Minimize the window between CI pass and merge to reduce the chance of new conflicts appearing.
3. **Consider merge queues**: For high-throughput periods, use GitHub merge queues or sequence integrations to avoid the conflict-resolve-push-wait-conflict loop.
4. **Use additive-only patterns**: Ensure shared registration files follow purely additive patterns (append to lists, add new `else if` branches) to make conflicts mechanical to resolve.

---

## 24. Pitfall: Automated Conflict Resolution Introduces Syntax Corruption

### Symptoms
After automated (subagent) merge conflict resolution, CI fails with parse errors like `Expected to find ')'` in files containing deeply nested expressions.

### Root Cause
Automated conflict resolvers that merge both sides of a conflict in complex nested code (e.g., 6-level nested ternary expressions) can drop closing delimiters (parentheses, brackets, braces) because the resolver focuses on content lines rather than structural integrity. In Issue #128, a conflict resolver dropped 6 closing `)` characters from nested ternary expressions in `dashboard_page.dart`.

### Corrective Action & Best Practice
1. **Always validate after automated conflict resolution**: Run `dart analyze` (or equivalent linter/compiler) immediately after resolving conflicts and before committing. Never trust automated resolution of complex expressions.
2. **Refactor fragile patterns**: Deeply nested ternary expressions (4+ levels) should be refactored into lookup maps or helper methods:
   ```dart
   // Instead of nested ternaries:
   static const _datasetIcons = {
     DatasetIds.bankAtms: Icons.atm,
     DatasetIds.doctorsLicenses: Icons.badge_outlined,
     DatasetIds.vehicleRecalls: Icons.warning_amber_outlined,
     // ...
   };
   final icon = _datasetIcons[item.id] ?? Icons.cell_tower;
   ```
3. **Keep conflict zones small**: Structure shared registration code so each dataset's addition is a self-contained block (e.g., a map entry) rather than a branch in a chain.

---

## 25. Pitfall: Hardcoded Collection Counts in Shared Constant Tests

### Symptoms
After merging a branch that adds a new dataset, a previously-passing test fails with: `Expected: <7> Actual: <8>` in `dataset_ids_test.dart`.

### Root Cause
The test hardcoded `expect(DatasetIds.all.length, 7)` which is fragile against any concurrent PR that also adds a dataset to the `all` list. When our PR's merge brought in the new dataset, the count became 8 but the test still expected 7.

### Corrective Action & Best Practice
1. **Avoid hardcoded counts for extensible collections**: Use dynamic assertions that verify membership rather than exact size:
   ```dart
   expect(allIds.contains(DatasetIds.vehicleRecalls), isTrue);
   expect(allIds.contains(DatasetIds.carImporters), isTrue);
   // Verify no duplicates instead of exact count:
   expect(allIds.toSet().length, allIds.length);
   ```
2. **When count assertions are necessary**: Use `greaterThanOrEqualTo` to be resilient against concurrent additions:
   ```dart
   expect(allIds.length, greaterThanOrEqualTo(8));
   ```

---

## 26. Pitfall: Multi-Branch Version Auto-Bumping Divergence (Merge Conflicts)

### Symptoms
Integrating changes from `main` or another active branch into the issue development branch results in version conflicts inside `package.json`, `client/pubspec.yaml`, and `VERSION` files.

### Root Cause
The repository uses an automated pre-commit version bumping hook. When multiple developers or agents work on separate branches in parallel, each branch commits auto-bumped versions. Merging these branches creates conflicts in version fields.

### Corrective Action & Best Practice
1. **Resolve Version Conflict:** Resolve the conflict manually by choosing the highest version number (the maximum increment).
2. **Re-stage Auto-Versioned Files:** The auto-versioning hook runs during `git commit`, which changes the files again. Always run `git status` after a failed commit or automatic run, and re-stage (`git add .`) any files that were modified by hooks before committing again.

---

## 27. Pitfall: Downstream Test Coverage Gate Violations on Merged Code

### Symptoms
Pushing a verified, fully covered branch fails during pre-push hooks with coverage violations on files that were not modified by the current task (e.g. `local_market_bonds_notifier.dart`).

### Root Cause
Merging `main` brings in new features and classes implemented by other branches (which might have had mock-only or incomplete test coverage). If the current branch modifies any shared definitions (e.g. `DatasetIds.dart`) that these new classes import, the quality gates will re-evaluate coverage on all related files, triggering coverage failures for the merged, untested files.

### Corrective Action & Best Practice
Always run the full coverage check suite locally after a merge conflict resolution:
`flutter test --coverage && dart run tool/check_coverage.dart && node ../scripts/check-coverage-thresholds.js --client`
If any class has coverage gaps (e.g. untested Firestore streaming paths or filters), implement mock and fake Firestore unit tests using `noSuchMethod` dynamic delegation to raise the coverage to **100%** before pushing.

---

## 28. Pitfall: Static Analysis Failures from Subtyping Sealed Firestore Classes

### Symptoms
Pushing or compiling code fails with static analysis warnings:
`warning • The class 'Query' shouldn't be extended, mixed in, or implemented because it's sealed. Try composing instead of inheriting, or refer to the documentation of 'Query' for more information`

### Root Cause
The cloud firestore package seals classes like `Query`, `QueryDocumentSnapshot`, and `DocumentSnapshot`. Implementing these classes in tests to create fakes or mocks triggers analysis warnings, which are treated as blocker errors on CI/CD.

### Corrective Action & Best Practice
Always ignore `subtype_of_sealed_class` at the top of test files defining mock Firestore structures:
```dart
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
```
This allows tests to compile and run using lightweight fakes without triggering static checks failures.

---

## 29. Pitfall: Hebrew Pluralization and Unicode Character Mismatch in Includes Checks

### Symptoms
Unit tests checking keyword-based mock analysis (like `getMockRoadmapReview`) return incorrect scores (e.g. `Medium` instead of `Low`) for plural Hebrew nouns, causing assertions to fail.

### Root Cause
In Hebrew, pluralizing a noun does not simply append a suffix; it often changes the spelling of the word itself. For example, the singular word "Museum" is `"מוזיאון"` (ending with the final nun `ן`, char code 1503), but its plural form "Museums" is `"מוזיאונים"` (which uses a regular nun `נ`, char code 1504, followed by `י` and `ם`). Therefore, `"מוזיאונים".includes("מוזיאון")` evaluates to `false` in JavaScript/TypeScript because the character codes for `ן` (1503) and `נ` (1504) are different.

### Corrective Action & Best Practice
1. **Explicit Keyword Checks**: When writing keyword matching logic for Hebrew strings, check for both the word ending in a final nun/mem/tsadi and its root/non-final counterpart (e.g., check `t.includes("מוזיאון") || t.includes("מוזיאונ")`).
2. **Match Singular Form in Tests**: When writing test cases targeting specific keywords, use titles that contain the exact singular word as a separate token (e.g., use `"מוזיאון תל אביב"` which contains `"מוזיאון"`, rather than the pluralized `"מוזיאונים בישראל"`).

---

## 30. Pitfall: Missing Firestore Trigger Mocks in Unrelated Test Suites

### Symptoms
Adding a new Firestore trigger (e.g., `.firestore.document("...")`) inside `src/index.ts` causes unrelated test files (like `manual_sync.test.ts`, `ticker.test.ts`, `ai_search_service.test.ts`) to fail during import with `TypeError: Cannot read properties of undefined (reading 'document')`.

### Root Cause
Many backend test files mock `firebase-functions/v1` partially or dynamically using `vi.mock("firebase-functions/v1")`. When they mock `runWith`, they only return properties they expect their specific tested endpoints to use (e.g., `https`, `pubsub`, `auth`). When `src/index.ts` is imported, all top-level Cloud Function exports are evaluated. If a new export uses a nested trigger builder that was not mock-defined (e.g. `runWith(...).firestore.document`), it will crash with a `TypeError`.

### Corrective Action & Best Practice
Always ensure that the global `firebase-functions/v1` mock returned by `runWith` is robust and includes stub properties for all trigger types used across `src/index.ts` (e.g. `firestore: { document: vi.fn().mockReturnValue({ onCreate: triggerMock }) }`). When adding a new trigger type to `index.ts`, check and update all other tests that mock `firebase-functions/v1` to prevent import-time failures.

---

## 31. Pitfall: Dart Mock HTTP Client UTF-8 Response Encoding Exception

### Symptoms
In Dart widget/unit tests, returning non-ASCII strings (such as Hebrew characters) inside a mock `http.Response` body throws an `Invalid argument (string): Contains invalid characters` exception.

### Root Cause
By default, the Dart `http.Response` constructor decodes/encodes body strings using Latin-1 (ISO-8859-1) if no content-type encoding is specified. Since Latin-1 only supports characters in the range 0-255, passing Hebrew characters (which fall under UTF-8 / higher code points) triggers an invalid character exception.

### Corrective Action & Best Practice
When constructing mock HTTP responses in Dart that contain Hebrew or non-ASCII characters, always explicitly specify the UTF-8 charset in the headers parameter:
```dart
return http.Response(
  jsonEncode({...}),
  200,
  headers: {
    'content-type': 'application/json; charset=utf-8',
  },
);
```

---

## 32. Pitfall: Missing Braces Cascading UI Compile Failure

### Symptoms
Compiling the Flutter application or running tests fails with numerous cascading errors complaining that class methods are not defined or that widget classes are not types.

### Root Cause
A missing closing brace `}` on a class method (e.g. at the end of a long widget build helper) causes the Dart analyzer to parse all subsequent class methods as nested closures inside that method. This prematurely shifts the class boundary, preventing the analyzer from resolving top-level class declarations and methods correctly.

### Corrective Action & Best Practice
Use editor folding or formatting tools (`dart format`) to verify brace balance when editing large source files. If a compiler suddenly reports that a method is undefined or that a sibling class isn't a type, check the immediately preceding method for a missing closing brace `}`.

