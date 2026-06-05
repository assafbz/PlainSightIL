# Lessons Learned: Optimize CI Test Speed (Issue #107)

## 1. Cycle Executive Summary
This cycle successfully optimized the GitHub Actions CI workflows for backend, client, and E2E tests. By implementing proper caching for npm dependencies, Playwright browsers, and Flutter build directories, and by declaring `firebase-tools` as a local devDependency, we dramatically reduce redundant file downloads and rebuild overhead.

## 2. Pitfalls & Rejection Loops Analysis
- **Hurdle/Loop 1**: On-the-fly downloads of CLI tools.
  - **Root Cause**: The CI workflows relied on `npx firebase-tools` without declaring it as a project dependency. Consequently, the runner downloaded the entire `firebase-tools` package (which is large) on every single workflow run.
  - **Resolution**: Added `"firebase-tools"` to the devDependencies of both `package.json` (root) and `backend/functions/package.json`.
  - **Prevention**: Always declare large CLI tools used in CI runs in the project's dependency configurations so they are captured by Node setup caching.
- **Hurdle/Loop 2**: Missing Coverage Files.
  - **Root Cause**: Running `flutter test` without the `--coverage` flag prevented the generation of `lcov.info`, which caused the subsequent coverage check script to fail.
  - **Resolution**: Ran `flutter test --coverage` to populate the directory.

## 3. Documentation & Playbook Updates
None. The changes are standard GitHub Actions optimizations.

## 4. Code Cleanup & Refactoring
- Removed the redundant Java setup step from `flutter_ci.yml` since Dart unit and widget tests do not require a JVM.

## 5. Recommendations for Future Cycles
- **Optimize CI Workflows**: Keep workflows lean by only setting up required tools. Avoid duplicate Node/Java setups if a job does not specifically require them.
- **Use Dependency Caching**: Always ensure `actions/setup-node` caches all relevant `package-lock.json` paths in a multi-package repository.
