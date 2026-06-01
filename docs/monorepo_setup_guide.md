# PlainSightIL: Monorepo Setup & Developer Runbook

Welcome to **PlainSightIL**! This guide describes how to configure, run, test, and troubleshoot your local development environment for the PlainSightIL monorepo.

---

## 📂 Monorepo Structure

```
PlainSightIL/
├── client/          # Flutter/Dart native client (iOS, Android, WebAssembly)
├── backend/         # Firebase Functions, Firestore security rules, indexes
├── .agents/         # Multi-agent SDLC configs, playbooks, tools, git hooks
├── .ai_context/     # LLM and Agent ground-truth system specs
└── docs/            # Product requirements, designs, and developer runbooks
```

---

## 🛠️ System Prerequisites

Ensure you have the following installed on your system before proceeding:

1. **Flutter SDK**: `^3.12.0` (which includes Dart SDK `^3.0.0`).
2. **Node.js**: `v20.x` (LTS recommended) and **npm**.
3. **Firebase CLI**: Installed globally via `npm install -g firebase-tools`.
4. **Java Runtime Environment (JRE)**: Version 11 or higher (required by Firebase Emulator Suite to run the local Firestore emulator).

---

## 🚀 Environment Setup

Follow these steps to set up the project layers:

### Step 1: Install Git SDLC Hooks
PlainSightIL uses custom pre-commit and pre-push hooks to enforce SDLC compliance, branch naming, and linter check passes before pushes.
```bash
# From the repository root:
chmod +x .agents/bin/install-hooks.sh
./.agents/bin/install-hooks.sh
```
*Note: In emergency conditions, SDLC hooks can be bypassed by prepending `SKIP_SDLC=1` to your git command.*

### Step 2: Install Backend Dependencies
```bash
cd backend/functions
npm install
```

### Step 3: Install Client Dependencies
```bash
cd client
flutter pub get
```

---

## 💻 Running the Local Emulators

The backend uses the **Firebase Local Emulator Suite** to run Firestore and Cloud Functions locally without modifying production cloud resources.

### 1. Port Allocation
The project uses custom ports configured in [firebase.json](file:///Users/abenzaken/Dev/PlainSightIL/backend/firebase.json):
*   **Firestore Emulator**: Port `8081`
*   **Functions Emulator**: Port `5002`
*   **Emulator UI**: Port `4001` (accessible via web browser at `http://localhost:4001`)

### 2. Start the Backend Emulators
```bash
cd backend/functions
# Builds TypeScript and starts the emulators
npm run serve
```

### 3. Connect the Client App
The client connects to the local emulator in `client/lib/main.dart` automatically:
```dart
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8081);
```
By default, the client app initializes in **Offline Mock Mode** via the `AppStateNotifier.isTesting = true` flag. This populates the UI with hardcoded data lists so developers and tests can run instantly without running the Firebase emulators. 

To run against the local emulators and test scraper synchronization:
1. Open [client/lib/core/state/app_state.dart](file:///Users/abenzaken/Dev/PlainSightIL/client/lib/core/state/app_state.dart).
2. Set `static bool isTesting = false;` on line 10.
3. Run the client (see below).

---

## 📱 Running the Client Application

Run the Flutter client application on your target platform of choice.

```bash
cd client

# List available devices (simulators, browsers, physical devices)
flutter devices

# Run on macOS / Chrome (for development convenience)
flutter run -d chrome

# Run on a running mobile simulator / connected device
flutter run
```

---

## 🧪 Verification & Testing Commands

To pass automated quality gates, ensure the following commands run successfully:

### 1. Client Analysis & Unit Tests
```bash
cd client

# Run Dart analysis and verify styling/linting rules
flutter analyze

# Run all unit/widget tests
flutter test

# Run tests with HTML coverage output
flutter test --coverage
```

### 2. Backend Linting & Unit Tests
```bash
cd backend/functions

# Run ESLint checking
npm run lint

# Check formatting with Prettier
npm run format:check

# Execute TypeScript unit tests using Vitest
npm run test
```

---

## 🔍 Troubleshooting Guide

### 1. "Port 8080/8081 Taken" on Emulator Start
**Problem:** Starting the Firebase emulators fails with a message indicating that a port is already in use.  
**Solution:** Locate and terminate the process holding the port:
```bash
# Check if a process is using port 8081
lsof -i :8081

# Kill the process using its PID
kill -9 <PID>
```
*Note: Make sure to check `firebase.json` for all mapped ports if the conflict persists.*

### 2. "FirebaseException: type 'FirebaseException' is not a subtype of 'JavaScriptObject'" (Web target)
**Problem:** The client app crashes on launch with a web-interop casting error when run in Chrome.  
**Solution:** This occurs if the app attempts firestore calls before `Firebase.initializeApp()` resolves. Make sure Firebase is initialized inside `main()` in [client/lib/main.dart](file:///Users/abenzaken/Dev/PlainSightIL/client/lib/main.dart).

### 3. Git Hooks block commit or push
**Problem:** Git commit/push rejected due to failing linter or test rules.  
**Solution:** 
* Ensure your branch name matches the regex `(agents|dev)/<issue_id>-<desc>` (e.g. `agents/102-fix-layout`).
* Make sure you ran `dart format .` in the client directory and `npm run format` in the backend functions directory.
* Correct any compiler or linter warnings reported.
