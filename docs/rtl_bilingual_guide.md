# PlainSightIL: RTL & Bilingual Layout Guidelines

PlainSightIL is designed primarily for Israeli citizens, which means that **Right-to-Left (RTL) Hebrew** is our primary layout direction. However, the app supports seamless translation to **Left-to-Right (LTR) English**. 

To maintain visual symmetry and prevent UI overflows, all layouts must be completely independent of absolute horizontal positions.

---

## 🎨 Layout Direction Rules (Flutter / Dart)

### 1. The Cardinal Rule: Banish "Left" and "Right"
You must **never** hardcode absolute horizontal directions in padding, margins, borders, alignments, or positioning. Instead, use their **Directional** equivalents:

| Banned Absolute Class | Mandatory Directional Equivalent |
| :--- | :--- |
| `EdgeInsets.left(...)` / `EdgeInsets.right(...)` | `EdgeInsetsDirectional.only(start: ..., end: ...)` |
| `EdgeInsets.fromLTRB(l, t, r, b)` | `EdgeInsetsDirectional.fromSTEB(start, top, end, bottom)` |
| `Alignment.topLeft` / `Alignment.topRight` | `AlignmentDirectional.topStart` / `AlignmentDirectional.topEnd` |
| `Alignment.centerLeft` / `Alignment.centerRight` | `AlignmentDirectional.centerStart` / `AlignmentDirectional.centerEnd` |
| `Border(left: ...)` / `Border(right: ...)` | `BorderDirectional(start: ..., end: ...)` |
| `Positioned(left: ...)` / `Positioned(right: ...)` | `PositionedDirectional(start: ..., end: ...)` |

### 2. Relative Layout Direction Examples

#### Standard Card Padding & Border Alignment:
```dart
// AVOID: Absolute boundaries (will look reversed in English/Hebrew)
Widget buildCard() {
  return Container(
    padding: const EdgeInsets.only(left: 16.0, right: 8.0),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Colors.blue, width: 4.0)),
    ),
    child: const Text('Hello'),
  );
}

// RECOMMENDED: Directional boundaries (automatically mirrors based on directionality)
Widget buildCard() {
  return Container(
    padding: const EdgeInsetsDirectional.only(start: 16.0, end: 8.0),
    decoration: const BoxDecoration(
      border: BorderDirectional(start: BorderSide(color: Colors.blue, width: 4.0)),
    ),
    child: const Text('Hello'),
  );
}
```

#### Overlay Positioned Pins:
```dart
// AVOID: Pin is locked to the left side regardless of text direction
Positioned(
  left: 12,
  top: 8,
  child: Icon(Icons.star),
)

// RECOMMENDED: Pin stays at the starting edge
PositionedDirectional(
  start: 12,
  top: 8,
  child: Icon(Icons.star),
)
```

---

## ✍️ Bidirectional Text (BiDi) Handling

When rendering Hebrew sentences that include English characters (like operator names "Cellcom", model names, or serial numbers), the browser/system layout engine can display characters in an incorrect order.

### 1. Unicode Control Characters
To force text elements to respect a specific directionality, wrap them with Unicode direction markers:
*   **LTR Marker (LRM)**: `\u200E` (or `\u{200E}` in Dart)
*   **RTL Marker (RLM)**: `\u200F` (or `\u{200F}` in Dart)

```dart
// Enforce LTR rendering on compound serial codes within Hebrew sentences:
final String serialNumber = "CELL-4921A";
final String displayString = "מספר אתר: \u{200E}$serialNumber";
```

### 2. Text Alignment
Always align text dynamically based on the directionality rather than relying on center-only alignments:
```dart
Text(
  titleText,
  textAlign: TextAlign.start, // Automatically aligns to right in Hebrew, left in English
)
```

---

## 🧭 Navigation Overlays & Gestures

### 1. Slide-out Drawers
The main navigation drawer slide direction must match the reading flow:
*   In **Hebrew (RTL)**: Slides out from the **Right** edge.
*   In **English (LTR)**: Slides out from the **Left** edge.

In Flutter, using `Scaffold(drawer: ...)` automatically binds the drawer to the correct starting edge depending on the active `Directionality` widget. Do not use `endDrawer` unless you specifically want the drawer on the trailing edge.

### 2. Back Buttons & Chevron Icons
Arrow indicators showing screen navigation history must mirror properly. A "back" action points to the left in LTR, but to the right in RTL.
Use standard widgets like `IconButton(icon: Icon(Icons.arrow_back))` inside a directional context, or use standard platform components (`AppBar`) which automatically handle back button indicators.

---

## 🌐 CSS Equivalents (For Web Targets / Stitch Mockups)

If writing CSS styles or generating layouts in Stitch, use **CSS Logical Properties** rather than physical ones:

| Physical CSS Property | Logical Equivalent CSS Property |
| :--- | :--- |
| `margin-left` / `margin-right` | `margin-inline-start` / `margin-inline-end` |
| `padding-left` / `padding-right` | `padding-inline-start` / `padding-inline-end` |
| `left` / `right` | `inset-inline-start` / `inset-inline-end` |
| `border-left` / `border-right` | `border-inline-start` / `border-inline-end` |
| `border-top-left-radius` | `border-start-start-radius` |

---

## 🚨 Visual Verification Checklist
Before submitting a PR for QA, verify the layout across both locales:
1. **Locale Toggle**: Change the language between English and Hebrew.
2. **Horizontal Symmetry Check**: Check that all margins and alignments mirror correctly.
3. **No Clipped Text**: Confirm that labels with long translated text do not overlap, clip, or trigger layout exceptions (like the yellow-and-black overflow banner in Flutter). Use `Flexible`, `Expanded`, or `overflow: TextOverflow.ellipsis` on `Text` widgets.
