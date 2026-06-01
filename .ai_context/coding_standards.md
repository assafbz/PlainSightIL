# PlainSightIL: Coding Standards & Quality Guardrails

This document establishes development standards, code quality checks, test-coverage limits, and error handling policies across the PlainSightIL codebase. Compliance is required for all commits and pull requests.

---

## 1. Linting & Formatting

Consistent syntax structures ensure that code remains highly readable and easily parseable by code verification pipelines and developer agents.

### 1.1 Client-Side (Dart / Flutter)
*   **Automatic Formatting**: Run `dart format` over all modified files prior to staging. A maximum line length of **80 characters** is enforced by Dart standard guidelines.
*   **Static Analysis**: Code must compile without errors or warnings under the rules defined in [analysis_options.yaml](file:///Users/abenzaken/Dev/PlainSightIL/client/analysis_options.yaml).
*   **Naming Conventions**:
    *   **Classes, Enums, Mixins**: `PascalCase` (e.g., `CellularAntennaCard`).
    *   **Methods, Variables, Constants**: `camelCase` (e.g., `antennaId`, `fetchCoordinates()`).
    *   **Directories, Files, Packages, Assets**: `snake_case` (e.g., `cellular_antennas/`, `antennas_bloc.dart`).

### 1.2 Backend-Side (Node.js / TypeScript)
*   **Formatting**: Prettier is used for backend code formatting. Double quotes and semicolons are required.
*   **Linting**: Strict ESLint configs with TypeScript-specific validation rules. No implicit `any` types allowed.

---

## 2. Testing Requirements

A robust testing hierarchy is enforced to guarantee system stability and prevent regressions during updates to the dataset schemas.

### 2.1 Code Coverage Rules
*   **No Uncovered Logic**: Feature additions must include corresponding tests.
*   **Domain & Data Layers**: 90%+ unit test coverage required.
*   **Presentation Layer**: Cubits/BLoCs require 100% flow coverage (testing all event-to-state routes).

### 2.2 Test Structure & Patterns
*   **Unit Tests**: Must isolate the unit under test. Use **`mocktail`** or **`mockito`** for mocking dependencies (repositories, data sources).
*   **Integration Tests**: Flutter driver tests must verify complete user paths (e.g., loading the map, panning, tapping an antenna, verifying details bottom sheet).
*   **Naming Convention**: Match the path of the target file under the test directory, appending `_test` to the filename. E.g., `lib/features/water_level/domain/usecases/get_water_level.dart` tests must live in `test/features/water_level/domain/usecases/get_water_level_test.dart`.

```dart
// Standard test template pattern for Use Cases
void main() {
  late GetWaterLevel usecase;
  late MockWaterRepository mockRepository;

  setUp(() {
    mockRepository = MockWaterRepository();
    usecase = GetWaterLevel(mockRepository);
  });

  test('should get water levels from the repository', () async {
    // Arrange
    when(() => mockRepository.getLevels()).thenAnswer((_) async => Right(tWaterLevels));
    // Act
    final result = await usecase(NoParams());
    // Assert
    expect(result, Right(tWaterLevels));
    verify(() => mockRepository.getLevels()).called(1);
  });
}
```

---

## 3. Error Handling & Exception Management

Exceptions must be intercepted at the boundaries of the system to prevent raw crashes or unhelpful error messages from reaching the client interface.

### 3.1 Exception Mapping Architecture
*   **Data Source Failures**: Remote API/database queries throwing exceptions (e.g., `FirebaseException`, `SocketException`) must be caught at the **Data Source** level and rethrown as custom, unified exceptions:
    - `ServerException`: Database/API connection timeouts or failures.
    - `CacheException`: Local Isar read/write corruption or failures.
*   **Repository Failures**: Repositories catch custom exceptions and return a functional functional-programming container: **`Either<Failure, Success>`** using the `fpdart` or `dartz` patterns.
*   **State Failures**: BLoCs must map `Failure` types to specific failure states (e.g., `AntennaFailure(message: '...')`) for display in the UI as styled snackbars or banners.

```dart
// Custom Failure definition in domain/errors/failures.dart
abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure(String message) : super(message);
}
```

### 3.2 Logging Protocols
*   **Debug Environment**: Log structured exceptions to the console with log severity markers (`[INFO]`, `[WARN]`, `[ERROR]`).
*   **Production Environment**:
    *   **Client**: Route uncaught errors and repository failures to **Firebase Crashlytics** via the Crashlytics SDK wrapper.
    *   **Backend Cloud Functions**: Log errors via `firebase-functions/logger`. Never use raw `console.log` for errors; use `logger.error` to retain metadata and stack traces.

---

## 4. SDLC Compliance & Multi-Agent Workflow

Every new development task—including new features, bug fixes, and code refactoring—must strictly adhere to the Multi-Agent SDLC Orchestration framework defined in [AGENTS.md](file:///Users/abenzaken/Dev/PlainSightIL/.agents/AGENTS.md). Direct updates or bypasses of these quality gates are prohibited.

### 4.1 Enforced Lifecycle Sequences
No development changes may bypass their respective lifecycle stages:
- **Features**: `triage` -> `discovery` (output: `PRD.md`) -> `ui_ux_design` (output: `DESIGN.md`) -> `architecture_design` (output: `TDD.md`) -> `security_audit` (output: `SECURITY.md`) -> `blueprinting` (output: `BLUEPRINT.md`) -> `implementation` -> `qa_validation` (output: `QA_REPORT.md`) -> `lessons_learned` (output: `LESSONS_LEARNED.md`) -> `merge_approval`.
- **Bugs**: `triage` -> `qa_reproduction` (output: `QA_REPRODUCTION_REPORT.md`) -> `blueprinting` -> `implementation` -> `qa_validation` -> `lessons_learned` (output: `LESSONS_LEARNED.md`) -> `merge_approval`.
- **Refactors**: `triage` -> `architecture_design` (output: `TDD.md`) -> `blueprinting` -> `implementation` -> `qa_validation` -> `lessons_learned` (output: `LESSONS_LEARNED.md`) -> `merge_approval`.

### 4.2 Gate Review Controls
- Artifacts must be generated and linked in the active issue file under `.agents/state/active_issues/` before moving to subsequent phases.
- Phases designated with a Human-in-the-Loop (HITL) gate require review and manual sign-off by updating the `hitl_approved_by` field with the reviewer's username prior to transition.

---

## 5. In-Code Documentation Standards

To ensure code remains highly readable and self-documenting for both developers and AI agents, all contributors must strictly adhere to the following inline commenting rules:

### 5.1 Client-Side (Dart / Flutter)
*   **API Documentation**: Document all public classes, methods, fields, constructors, and extensions using three-slash documentation comments (`///`). Markdown formatting is supported.
*   **Parameter & Return Info**: Clearly explain any non-obvious parameters, preconditions, return values, or side effects inside the doc comment.
*   **Complex Math & Painting**: For custom widgets, `CustomPainter` canvas drawings, animations, or layout calculations, include explicit inline comments explaining the formula, coordinate systems, or pixel transformations used.

```dart
/// A custom painter that draws a radar scan layout.
///
/// Maps coordinates relative to [centerPoint] using a max radius of [maxRadius].
class RadarGridPainter extends CustomPainter {
  /// The center point of the radar grid in screen space.
  final Offset centerPoint;
  
  /// The maximum scanning radius.
  final double maxRadius;
  
  const RadarGridPainter({required this.centerPoint, required this.maxRadius});
  
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Calculate relative scale delta based on canvas dimensions to prevent overflow
    final double scale = size.width / (maxRadius * 2);
    // ...
  }
}
```

### 5.2 Backend-Side (TypeScript / Node.js)
*   **JSDoc Standards**: Document all exported functions, interfaces, modules, and parameters using block-level JSDoc comments (`/** ... */`).
*   **Types vs Descriptions**: Avoid redundancy in JSDoc parameters where TypeScript types already specify the signature. Focus descriptions on the semantic meaning of the values.

```typescript
/**
 * Synchronizes gov cellular antennas API records with the target Firestore buffer.
 * @param db Firestore database instance.
 * @param resourceId Official resource identifier from data.gov.il.
 * @returns Object containing the synchronization outcome status and processed count.
 * @throws AxiosError if the government endpoint is unreachable.
 */
export async function scrapeAndSyncAntennas(
  db: admin.firestore.Firestore,
  resourceId: string,
): Promise<{ success: boolean; count: number }> {
  // ...
}
```

### 5.3 Commenting Best Practices (Common)
*   **Explain "Why", Not "What"**: Comments should focus on explaining *why* a particular workaround, optimization, or logic branch was implemented, not *what* the code does (the code should read clearly by itself).
*   **TODO Format**: Tag remaining tasks or technical debt with structured TODO comments that include issue or ticket context:
    ```
    // TODO: (Issue #104) Optimize geohash length mapping to radius ranges.
    ```


