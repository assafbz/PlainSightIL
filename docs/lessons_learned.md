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

---

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

