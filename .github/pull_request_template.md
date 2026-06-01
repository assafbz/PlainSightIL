## Description
Please include a summary of the changes and the related issue.

Fixes # (issue ID or branch issue number)

## Type of Change
- [ ] Feature (requires PRD, DESIGN, TDD, SECURITY, BLUEPRINT, QA_REPORT)
- [ ] Bug Fix (requires QA_REPRODUCTION, BLUEPRINT, QA_REPORT)
- [ ] Refactoring (requires TDD, BLUEPRINT, QA_REPORT)

## Multi-Agent SDLC Quality Gates Checklist
Please check off all the gates that have been successfully passed for this task:

### 1. Phase Deliverables
*Refer to `.agents/state/issue_<issue_id>/` for files.*
- [ ] **Discovery**: `PRD.md` is complete and has HITL sign-off (for features).
- [ ] **UI/UX Design**: `DESIGN.md` is complete and has HITL sign-off (for features).
- [ ] **Architecture Design**: `TDD.md` is complete (for features/refactors).
- [ ] **Security Gate**: `SECURITY.md` is complete and has HITL sign-off (for features).
- [ ] **Blueprinting**: `BLUEPRINT.md` checklist is defined and all tasks are completed.
- [ ] **QA Validation**: `QA_REPORT.md` is complete, verifying all test requirements.

### 2. Static Analysis & Local Lints
- [ ] Code formatting applied:
  - Client: `dart format .`
  - Backend: `npm run format`
- [ ] Linter is clean:
  - Client: `flutter analyze` passes with no errors/warnings.
  - Backend: `npm run lint` passes with no errors/warnings.
- [ ] Typescript compilation passes: `npm run build` (backend).

### 3. Automated & Coverage Tests
- [ ] Domain & Data layers have **90%+** unit test coverage.
- [ ] Cubits/BLoCs have **100%** event-to-state flow coverage.
- [ ] Local tests run successfully:
  - Client: `flutter test`
  - Backend: `npm run test` (Vitest)

### 4. Experiential & Manual QA (for UI/UX changes)
- [ ] Layout verified on mobile viewports:
  - [ ] Compact Mobile (375x667)
  - [ ] Standard Mobile (393x852)
  - [ ] Tablet (820x1180)
- [ ] RTL Localization (Hebrew) layout and bidirectional text mirror correctly.
- [ ] Checked all system states:
  - [ ] Empty state (no data matching filters)
  - [ ] Offline/No Network state (shows snackbar/banner, fallback cache)
  - [ ] Slow Network state (skeleton loading frames)
  - [ ] Failed API Fetch state (friendly description and Retry CTA)
