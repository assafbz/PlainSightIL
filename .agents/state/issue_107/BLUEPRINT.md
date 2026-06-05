# Implementation Blueprint: Optimize CI Test Speed (Issue #107)

## 1. File Modification Checklist
- `[ ]` [package.json](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/optimize-ci-test-speed/package.json) - Add `firebase-tools` to root devDependencies.
- `[ ]` [package.json](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/optimize-ci-test-speed/backend/functions/package.json) - Add `firebase-tools` to backend/functions devDependencies.
- `[ ]` [backend_ci.yml](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/optimize-ci-test-speed/.github/workflows/backend_ci.yml) - Run Firestore emulator check using local `firebase-tools` from functions folder.
- `[ ]` [e2e_ci.yml](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/optimize-ci-test-speed/.github/workflows/e2e_ci.yml) - Add caching configs for npm package locks, Playwright browser, and Flutter build tool.
- `[ ]` [flutter_ci.yml](file:///Users/abenzaken/.gemini/antigravity/worktrees/PlainSightIL/optimize-ci-test-speed/.github/workflows/flutter_ci.yml) - Remove Java setup and add caching for client build artifacts.

## 2. Coding Tasks Checklist
- `[ ]` Task 1: Add `"firebase-tools": "^13.10.0"` to the `devDependencies` of the root `package.json`.
- `[ ]` Task 2: Add `"firebase-tools": "^13.10.0"` to the `devDependencies` of `backend/functions/package.json`.
- `[ ]` Task 3: In `.github/workflows/backend_ci.yml`, change the working directory of "Validate Firestore Rules" to `backend/functions` and modify the command to `npx firebase-tools emulators:exec --project demo-plainsightil --config ../firebase.json --only firestore "echo 'Firestore rules verified successfully'"`.
- `[ ]` Task 4: In `.github/workflows/e2e_ci.yml`, update `cache-dependency-path` of `setup-node` to cover both root and functions lockfiles.
- `[ ]` Task 5: In `.github/workflows/e2e_ci.yml`, add actions/cache step for `~/.cache/ms-playwright`, compute playwright version from `package-lock.json`, and split playwright install into `install-deps` (on cache hit) or `install --with-deps` (on cache miss).
- `[ ]` Task 6: In `.github/workflows/e2e_ci.yml`, add cache step for `client/.dart_tool` to cache compilation outputs.
- `[ ]` Task 7: In `.github/workflows/flutter_ci.yml`, remove the `Set up Java` step.
- `[ ]` Task 8: In `.github/workflows/flutter_ci.yml`, add cache step for `client/.dart_tool`.

## 3. Verification Targets
- Confirm all Node dependency changes install cleanly without error:
  ```bash
  npm install
  npm install --prefix backend/functions
  ```
- Push to branch and monitor GitHub Action runs to verify execution time reduction.
