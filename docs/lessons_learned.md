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

## 6. Pitfall: Child Process Spawning Deprecation Warnings (`[DEP0190]`) on Non-Windows Hosts

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

## 7. Pitfall: GCP Metadata Server Lookup Warnings in Local Dev (`MetadataLookupWarning`)

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

## 8. Pitfall: Strict Version Checking for Node Engines in Firebase CLI

### Symptoms
Setting the `engines.node` block in the functions `package.json` to comparison range values (such as `">=22"`) results in a crash during emulator load:
`Failed to load function definition from source: FirebaseError: Detected node engine >=22 in package.json, which is not a supported version. Valid versions are 20, 22, 24`

### Root Cause
The Firebase CLI parser does not support semver range operators for local Node engine checks and expects exact engine string keys like `"20"`, `"22"`, or `"24"`.

### Corrective Action & Best Practice
Keep the engines configuration set to the target deploy version (e.g. `"22"`), and suppress mismatch warnings locally by setting the `--no-deprecation` Node flag:
```javascript
const child = spawn('npx', ['firebase-tools', ...], {
  env: {
    ...process.env,
    NODE_OPTIONS: '--no-deprecation'
  }
});
```
