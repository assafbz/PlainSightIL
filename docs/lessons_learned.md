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
