# Multi-Agent SDLC Orchestration Configuration

This document acts as the master orchestration configuration file for the multi-agent framework running in the PlainSightIL workspace. It specifies the personas, execution order, state transition maps, and review loop definitions.

---

## 1. Metadata & Global Settings

```yaml
framework:
  name: "Antigravity SDLC Coordinator"
  version: "1.0.0"
  state_directory: ".agents/state/active_issues/"
  archive_directory: ".agents/state/archive/"
  playbook_directory: ".agents/skills/"
  git_branch_prefix: "agents/"
  default_target_milestone: "PlainSightIL v1.0"
  stitch:
    project_id: "10303868738682079846"
    project_title: "Israel Open Data Explorer"
```

---

## 2. Agent Personas Registry

Every agent is defined here along with their corresponding playbook path and access scope:

```yaml
personas:
  product_manager:
    name: "Product Manager Agent"
    playbook: ".agents/skills/pm/SKILL.md"
    git_label: "status:discovery"
    role_description: "Translates high-level requests/issues into structured PRD requirements."
    tools_allowed: ["read_file", "write_file", "search_web"]

  system_architect:
    name: "System Architect Agent"
    playbook: ".agents/skills/architect/SKILL.md"
    git_label: "status:tech-design"
    role_description: "Creates high-level architecture designs and file modifications plans."
    tools_allowed: ["read_file", "write_file", "grep_search"]

  security_engineer:
    name: "Security Engineer Agent"
    playbook: ".agents/skills/security/SKILL.md"
    git_label: "status:security-audit"
    role_description: "Reviews technical designs and code changes for security vulnerabilities."
    tools_allowed: ["read_file", "write_file"]

  tech_lead:
    name: "Technical Lead Agent"
    playbook: ".agents/skills/tech_lead/SKILL.md"
    git_label: "status:blueprint"
    role_description: "Drafts implementation checklists and orchestrates the developer loop."
    tools_allowed: ["read_file", "write_file", "run_command"]

  senior_developer:
    name: "Senior Developer Agent"
    playbook: ".agents/skills/developer/SKILL.md"
    git_label: "status:development"
    role_description: "Executes implementation plans, creates files, edits code, and resolves bugs."
    tools_allowed: ["read_file", "write_file", "run_command", "replace_file_content", "multi_replace_file_content"]

  qa_engineer:
    name: "QA Engineer Agent"
    playbook: ".agents/skills/qa/SKILL.md"
    git_label: "status:qa-validation"
    role_description: "Formulates test specs and verifies code outputs against requirements."
    tools_allowed: ["read_file", "write_file", "run_command"]

  ui_ux_designer:
    name: "UI/UX Designer Agent"
    playbook: ".agents/skills/ui_ux_designer/SKILL.md"
    git_label: "status:ui-ux-design"
    role_description: "Designs interactive layout frameworks, color schemas, and style specifications."
    tools_allowed: ["read_file", "write_file"]

  lessons_learned:
    name: "Lessons Learned Agent"
    playbook: ".agents/skills/lessons_learned/SKILL.md"
    git_label: "status:lessons-learned"
    role_description: "Reviews the completed cycle, identifies pitfalls, updates guidelines/documentation, and refactors code to improve future cycles."
    tools_allowed: ["read_file", "write_file", "run_command", "replace_file_content", "multi_replace_file_content", "grep_search"]

```

---

## 3. Workflow Phase Mapping

Defines how different issue types flow sequentially through phases and which agents are assigned.

```yaml
lifecycle_paths:
  feature:
    phases:
      - id: "triage"
        assignee: "coordinator"
        next_phase: "discovery"
        hitl_gate: false

      - id: "discovery"
        assignee: "product_manager"
        output_file: "PRD.md"
        next_phase: "ui_ux_design"
        hitl_gate: true # Requires product review and sign-off

      - id: "ui_ux_design"
        assignee: "ui_ux_designer"
        output_file: "DESIGN.md"
        next_phase: "architecture_design"
        hitl_gate: true # Requires designer review and sign-off

      - id: "architecture_design"
        assignee: "system_architect"
        output_file: "TDD.md"
        next_phase: "security_audit"
        hitl_gate: false

      - id: "security_audit"
        assignee: "security_engineer"
        output_file: "SECURITY.md"
        next_phase: "blueprinting"
        hitl_gate: true # Requires architecture & security sign-off

      - id: "blueprinting"
        assignee: "tech_lead"
        output_file: "BLUEPRINT.md"
        next_phase: "implementation"
        hitl_gate: false

      - id: "qa_validation"
        assignee: "qa_engineer"
        output_file: "QA_REPORT.md"
        next_phase: "lessons_learned"
        hitl_gate: false

      - id: "lessons_learned"
        assignee: "lessons_learned"
        output_file: "LESSONS_LEARNED.md"
        next_phase: "merge_approval"
        hitl_gate: false

      - id: "merge_approval"
        assignee: "coordinator"
        hitl_gate: true # User must merge the Pull Request manually

  bug:
    phases:
      - id: "triage"
        assignee: "coordinator"
        next_phase: "qa_reproduction"
        hitl_gate: false

      - id: "qa_reproduction"
        assignee: "qa_engineer"
        output_file: "QA_REPRODUCTION_REPORT.md"
        next_phase: "blueprinting"
        hitl_gate: false

      - id: "blueprinting"
        assignee: "tech_lead"
        output_file: "BLUEPRINT.md"
        next_phase: "implementation"
        hitl_gate: false

      - id: "implementation"
        assignee: "senior_developer"
        next_phase: "qa_validation"
        hitl_gate: false

      - id: "qa_validation"
        assignee: "qa_engineer"
        output_file: "QA_REPORT.md"
        next_phase: "lessons_learned"
        hitl_gate: false

      - id: "lessons_learned"
        assignee: "lessons_learned"
        output_file: "LESSONS_LEARNED.md"
        next_phase: "merge_approval"
        hitl_gate: false

      - id: "merge_approval"
        assignee: "coordinator"
        hitl_gate: true

  refactor:
    phases:
      - id: "triage"
        assignee: "coordinator"
        next_phase: "architecture_design"
        hitl_gate: false

      - id: "architecture_design"
        assignee: "system_architect"
        output_file: "TDD.md"
        next_phase: "blueprinting"
        hitl_gate: true

      - id: "blueprinting"
        assignee: "tech_lead"
        output_file: "BLUEPRINT.md"
        next_phase: "implementation"
        hitl_gate: false

      - id: "implementation"
        assignee: "senior_developer"
        next_phase: "qa_validation"
        hitl_gate: false

      - id: "qa_validation"
        assignee: "qa_engineer"
        output_file: "QA_REPORT.md"
        next_phase: "lessons_learned"
        hitl_gate: false

      - id: "lessons_learned"
        assignee: "lessons_learned"
        output_file: "LESSONS_LEARNED.md"
        next_phase: "merge_approval"
        hitl_gate: false

      - id: "merge_approval"
        assignee: "coordinator"
        hitl_gate: true
```

---

## 4. Local Feedback Loop Triggers

Loops interrupt the default sequential mapping based on evaluation conditions:

```yaml
feedback_loops:
  - name: "Architect-Developer Blueprint Revision"
    trigger_condition: "QA or Tech Lead sets review_status to 'rejected' or 'changes-requested'"
    source_phase: "qa_validation"
    target_phase: "implementation"
    action: |
      Extract review details from the state audit log.
      Re-assign issue to the senior_developer.
      Set status to 'blueprint-revision'.
      Demote GitHub label back to 'status:development'.

  - name: "PM-Architect Requirements Clarification"
    trigger_condition: "Architect detects design impossibility or conflict with PRD"
    source_phase: "architecture_design"
    target_phase: "discovery"
    action: |
      Update issue state indicating clarification blocker.
      Re-assign issue to the product_manager.
      Set status to 'prd-revision'.
```
