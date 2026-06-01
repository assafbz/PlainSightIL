# UI/UX Specification: Cellular Permit Applications & Antennas Under Construction

This document details the interface layout specification, typography hierarchy, component structures, and motion requirements designed for the "Cellular Antennas Under Construction" (Permit Applications) dataset screen. These mockups have been generated in the project's Stitch design canvas.

*   **Stitch Project:** Israel Open Data Explorer
*   **English LTR Screen ID:** `projects/10303868738682079846/screens/137f4892d76247ca99d66b60b2f73ee8`
*   **Hebrew RTL Screen ID:** `projects/10303868738682079846/screens/af6ad8c79f7e4638bae3b2a008c8f2c8`

---

## 1. Visual Theme & Color Tokens

The screen inherits the global **Slate Dark Mode** and **Premium Glassmorphism** guidelines of the PlainSightIL design system.

### Color Tokens Used:
*   **Base Canvas:** `#090d16` (Deep slate background) with radial gradients of `#571bc1` (Violet) and `#38bdf8` (Cyan/Teal) to create a visual glow effect.
*   **Glass panels / Cards:** `rgba(15, 23, 42, 0.75)` with a `1px` border of `rgba(255, 255, 255, 0.08)`.
*   **Glow Accents:** `rgba(56, 189, 248, 0.15)` (Primary Cyan glow for active states).
*   **Semantic Borders:**
    *   **Approved Construction:** `hsl(195, 100%, 50%)` (Teal/Cyan) indicating approved permits currently undergoing active site setup.
    *   **Pending Review:** `hsl(38, 92%, 50%)` (Amber) indicating applications under review/pending approval.

---

## 2. Component Wireframe & Layout Architecture

The screen layout is divided into three key visual blocks in a mobile viewport:

```
+-------------------------------------------------------------+
| [Header App Bar]                                            |
| PlainSight IL / בגובה העיניים  [Menu (R)]  [Lang Toggle (L)]|
+-------------------------------------------------------------+
| [Map Visualizer Canvas]                                     |
|  - Dark theme base map layer                                |
|  - High-contrast circular glow pins                         |
|  - Status badge: 'Construction Permit' / 'היתר הקמה'        |
+-------------------------------------------------------------+
| [Glassmorphic Bottom Sheet] (Backdrop blur: 16px)           |
|  - Drag handle (40x5px pill, rounded)                       |
|  - Segmented Control: Active Towers | Construction Permits  |
|  - Search Input: Locality / Site ID (Cyan focus outline)    |
|  - Scrollable List View of Permit Cards:                    |
|    +---------------------------------------------------+    |
|    | Accent side border (4px)                          |    |
|    | Reference ID: #PRMT-2025-X                        |    |
|    | Submitted: 2025-09-01  | Operator: Partner/Cellcom|    |
|    | Locality: Tel Aviv     | Type: Ground/Mast        |    |
|    +---------------------------------------------------+    |
+-------------------------------------------------------------+
| [Floating Bottom Navigation Bar]                            |
| Home | Towers (Active) | Water | Budget | Alerts           |
+-------------------------------------------------------------+
```

---

## 3. Responsive Layout Guidelines

*   **Mobile breakpoint (< 600px):**
    *   Single-column layout using portrait orientation.
    *   Interactive elements (buttons, segmented controls, cards) must maintain touch targets of at least `48px x 48px` to accommodate thumb reach.
    *   Bottom sheet operates as an overlay covering up to 40% height (half-expanded result list) or 90% height (detailed permit information sheet).
*   **Tablet/Desktop breakpoint (> 600px):**
    *   Side-by-side grid split: 60% viewport width dedicated to the map visualizer (left pane) and 40% width dedicated to the scrollable filter list (right pane).
    *   Bottom sheet transitions into a static, floating side control panel.

---

## 4. Bilingual Mirroring (RTL/LTR) Rules

*   **Logical Property Alignment:** All elements utilize CSS logical properties rather than absolute physical sides (e.g. `margin-inline-start`, `padding-inline-end`, `border-start-start-radius`) to ensure the layout flips natively.
*   **Hebrew Font Face:** Applies **Assistant** for all Hebrew text blocks.
*   **English/Numerical Font Face:** Applies **Outfit** for all English text and numeric values (dates, coordinates, reference numbers).
*   **Visual Directionality:**
    *   **English (LTR):** Text aligned left; status borders on the left side of cards; hamburger menu on the left, language toggle ('HE') on the right.
    *   **Hebrew (RTL):** Text aligned right; status borders on the right side of cards; hamburger menu on the right, language toggle ('EN') on the left.

---

## 5. Micro-Animations & Interaction States

*   **Segmented Control Switch:** Swapping active filters should trigger a `150ms` linear scale transition with a soft fade indicator.
*   **Permit Cards Hover/Tap:** Cards translate `4px` inline-start (left in LTR, right in RTL) and increase backdrop saturation over a `150ms` cubic-bezier transition.
*   **Tap Active State:** Scales interactive buttons slightly down to `0.95x` to simulate a physical click.
*   **Skeleton Loader:** Cards display an animated HSL shimmer gradient moving from left to right while fetching data.
