# UI/UX Specification: Bank ATMs Map View

This document details the interface layout specification, typography hierarchy, component structures, and motion requirements designed for the "Bank ATMs" dataset screen. These screens have been designed and updated in the project's Stitch design canvas.

*   **Stitch Project:** Israel Open Data Explorer
*   **English LTR Screen ID:** `projects/10303868738682079846/screens/f9679a2695714e7888c087386dd394bd`
*   **Hebrew RTL Screen ID:** `projects/10303868738682079846/screens/e09d3d96dcc84e24ae1ec3b66817d324`

---

## 1. Visual Theme & Color Tokens

The screen inherits the global **Slate Dark Mode** and **Premium Glassmorphism** guidelines of the PlainSightIL design system.

### Color Tokens Used:
*   **Base Canvas:** `#090d16` (Deep slate background) with radial gradients of `#2e7d32` (Green/Financial) and `#38bdf8` (Cyan/Teal) to create a visual glow effect.
*   **Glass panels / Cards:** `rgba(15, 23, 42, 0.75)` with a `1px` border of `rgba(255, 255, 255, 0.08)`.
*   **Glow Accents:** `rgba(56, 189, 248, 0.15)` (Primary Cyan glow for active states) and `rgba(46, 125, 50, 0.15)` (Green glow for financial items).
*   **Semantic Borders:**
    *   **Bank ATM Cards:** `hsl(122, 45%, 33%)` (Green) indicating supported, active ATMs.

---

## 2. Component Wireframe & Layout Architecture

The screen layout is divided into three key visual blocks in a mobile viewport:

```
+-------------------------------------------------------------+
| [Header App Bar]                                            |
| PlainSight IL / בגובה העיניים  [Menu (R)]  [Lang Toggle (L)]|
+-------------------------------------------------------------+
| [Map Visualizer Canvas]                                     |
|  - Dark theme base map layer (CartoDB Dark All)             |
|  - High-contrast circular glow pins (Green for financial)   |
|  - Selected pin shows highlighted borders & glow            |
+-------------------------------------------------------------+
| [Map Controls Overlay]                                      |
|  - Recenter button (requires location access permissions)   |
|  - Map View / List View Toggle Switch                       |
+-------------------------------------------------------------+
| [Glassmorphic Bottom Sheet] (Backdrop blur: 16px)           |
|  - Drag handle (40x5px pill, rounded)                       |
|  - Search Input: City / Address / Bank Name                 |
|  - Filter Chips: Horizontal scrollable bank list            |
|  - Scrollable List View of ATM Cards:                       |
|    +---------------------------------------------------+    |
|    | Accent side border (4px Green)                    |    |
|    | Bank Name (e.g. Bank Hapoalim / בנק הפועלים)       |    |
|    | Address (e.g. Rothschild 42, Tel Aviv)            |    |
|    | ATM Location Description: Inside Branch / Wall    |    |
|    | Service chips (Cash, Deposit, Forex, Accessible)  |    |
|    | Last updated timestamp                            |    |
|    +---------------------------------------------------+    |
+-------------------------------------------------------------+
| [Floating Bottom Navigation Bar]                            |
| Home | Towers | Water | ATMs (Active) | Budget | Alerts     |
+-------------------------------------------------------------+
```

---

## 3. Responsive Layout Guidelines

*   **Mobile breakpoint (< 600px):**
    *   Single-column layout using portrait orientation.
    *   Interactive elements (buttons, segmented controls, cards) must maintain touch targets of at least `48px x 48px` to accommodate thumb reach.
    *   Bottom sheet operates as an overlay covering up to 40% height (half-expanded result list) or 90% height (detailed ATM information sheet).
*   **Tablet/Desktop breakpoint (> 600px):**
    *   Side-by-side grid split: 60% viewport width dedicated to the map visualizer (left pane) and 40% width dedicated to the scrollable filter list (right pane).
    *   Bottom sheet transitions into a static, floating side control panel.

---

## 4. Bilingual Mirroring (RTL/LTR) Rules

*   **Logical Property Alignment:** All elements utilize CSS logical properties rather than absolute physical sides (e.g. `margin-inline-start`, `padding-inline-end`, `border-start-start-radius`) to ensure the layout flips natively.
*   **Hebrew Font Face:** Applies **Assistant** for all Hebrew text blocks.
*   **English/Numerical Font Face:** Applies **Outfit** for all English text and numeric values (dates, coordinates, branch codes).
*   **Visual Directionality:**
    *   **English (LTR):** Text aligned left; status borders on the left side of cards; hamburger menu on the left, language toggle ('HE') on the right.
    *   **Hebrew (RTL):** Text aligned right; status borders on the right side of cards; hamburger menu on the right, language toggle ('EN') on the left.

---

## 5. Micro-Animations & Interaction States

*   **Map/List Toggle Switch:** Swapping active views triggers a `300ms` fade/slide transition between the map and list views.
*   **ATM Cards Hover/Tap:** Cards translate `4px` inline-start (left in LTR, right in RTL) and increase backdrop saturation over a `150ms` cubic-bezier transition.
*   **Tap Active State:** Scales interactive buttons slightly down to `0.95x` to simulate a physical click.
*   **Skeleton Loader:** Cards display an animated HSL shimmer gradient moving from left to right while fetching data.
