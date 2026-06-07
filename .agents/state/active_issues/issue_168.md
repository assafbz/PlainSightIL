---
issue_id: 168
title: "Refactor AppStateNotifier & Resolve Inconsistent Provider Registration"
type: refactor
current_phase: implementation
assigned_agent: senior_developer
status: in-progress
---

# Refactor AppStateNotifier & Resolve Inconsistent Provider Registration

Refactor the client application's root state consumption to prevent UI jank caused by rebuilding the entire MaterialApp widget tree, standardize the registration of composed sub-notifiers, and migrate pages to consume feature-scoped notifiers directly.

## 📋 Audit Log & Stage Transitions
- **2026-06-07 09:00:00**: Issue created and local tracking initialized.
