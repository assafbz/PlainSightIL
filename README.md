# PlainSightIL

**PlainSightIL** is a project dedicated to making the most important Israeli government open data accessible to citizens on mobile phones and tablets.

By converting dry, complex datasets from the official government database ([data.gov.il](https://data.gov.il/)) into clean, visual, and highly accessible utilities, PlainSightIL transforms raw public records into clear, everyday insights.

## 📄 Project Documentation

To understand the core values, strategic direction, and goals of this project, please refer to the following documents:

*   **[Vision & Mission Statement](docs/vision_and_mission.md)**: Our core operating principles, target audience impact, strategic pillars, and vision for the platform.
*   **[Product Definition Document](docs/product_definition.md)**: The execution strategy, dataset roadmap, UX/UI requirements, and prioritization framework.
*   **[UI/UX Design Specification & Styleguide](docs/design.md)**: The visual design system, HSL color palettes, typography scales, glassmorphism, responsive geometry, and micro-animation specifications (synchronized with Stitch project **Israel Open Data Explorer**, ID: `projects/10303868738682079846`).
*   **[High-Level Architecture & Technical Design](.ai_context/architecture.md)**: Proposes Flutter/Dart stack, clean directory design, data sync caches, state management, RTL localization, and HSL style guides.
*   **[Quality Gates Specification](.ai_context/quality_gates.md)**: Defines the criteria that code, designs, and documentation must satisfy before transitioning between SDLC phases or before code is merged.

## 🔄 SDLC & Development Workflow

To maintain absolute quality and traceability, every new development task (including features, bug fixes, and code refactoring) must go through the structured Multi-Agent SDLC Orchestration process. 

Detailed workflow phases, agent roles (Product Manager, Architect, UI/UX Designer, Tech Lead, Developer, Security, QA), and approval gates are defined in:
*   **[Multi-Agent Orchestration Framework (AGENTS.md)](.agents/AGENTS.md)**
*   **[Coding Standards & Quality Guardrails (coding_standards.md)](.ai_context/coding_standards.md#4-sdlc-compliance--multi-agent-workflow)**

---

## 🚀 Running the Project

To run both the backend (Firebase emulators) and client (Flutter web app) in parallel, run:

```bash
npm start
```

This will:
1. Compile the backend Cloud Functions (`tsc`).
2. Add the Homebrew OpenJDK path to the execution context on macOS to avoid Java discovery issues.
3. Start the Firebase emulator suite (Firestore and Functions).
4. Launch the Flutter client inside Google Chrome on port `8080`.

### 🛑 Terminating the Project

To shut down all services and clean up any orphaned emulator or web client processes running on ports `8081`, `5002`, `4001`, or `8080`, run:

```bash
npm run kill
```
