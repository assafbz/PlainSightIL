# UI/UX Specification: Travel Warnings (אזהרות מסע) Screen

This document details the interface layout specification, typography hierarchy, component structures, and motion requirements designed for the "Travel Warnings" dataset screen. These screens have been designed and updated in the project's Stitch design canvas.

*   **Stitch Project:** Israel Open Data Explorer
*   **English LTR Screen ID:** `projects/10303868738682079846/screens/ce80d5dd6eaa4106b71c5acf4b3db59b`
*   **Hebrew RTL Screen ID:** `projects/10303868738682079846/screens/5473a14d56d547ad87c1d58ae5074fb7`

---

## 1. Visual Theme & Color Tokens

The screen inherits the global **Slate Dark Mode** and **Premium Glassmorphism** guidelines of the PlainSightIL design system.

### Color Tokens Used:
*   **Base Canvas:** `#090d16` (Deep slate background) with radial gradients of `#2e7d32` (Green/Financial) and `#38bdf8` (Cyan/Teal) to create a visual glow effect.
*   **Glass panels / Cards:** `rgba(15, 23, 42, 0.75)` with a `1px` border of `rgba(255, 255, 255, 0.08)`.
*   **Glow Accents:** `rgba(56, 189, 248, 0.15)` (Primary Cyan glow for active states) and `rgba(244, 63, 94, 0.15)` (Red glow for warning items).
*   **Semantic Borders:**
    *   **Level 4 / High Threat:** `AppColors.danger` (Red) - indicating critical danger (avoid travel completely).
    *   **Level 3 / Medium Threat:** `AppColors.warning` (Orange/Amber) - indicating medium threat (avoid non-essential travel).
    *   **Level 2 / Low Threat:** `AppColors.primary` (Blue/Cyan) - indicating increased precautions.
    *   **Level 1 / Basic Info:** `AppColors.success` (Green) - indicating normal/basic recommendations or health information.

---

## 2. Component Wireframe & Layout Architecture

The screen layout is divided into three key visual blocks in a mobile viewport:

```
+-------------------------------------------------------------+
| [Header App Bar]                                            |
| PlainSight IL / בגובה העיניים  [Back (L)]      [Lang Toggle (R)]|
+-------------------------------------------------------------+
| [Search Bar]                                                |
|  - Soft-rounded high-contrast glassmorphic input            |
|  - "Search by country or continent" / "חפש לפי מדינה או יבשת"|
+-------------------------------------------------------------+
| [Continent Horizontal Filter Chips]                         |
|  - All | Africa | Asia | Europe | Pacific                   |
|  - הכל | אפריקה | אסיה | אירופה | פאסיפיק                    |
+-------------------------------------------------------------+
| [Scrollable List View of Travel Warning Cards]              |
|  - Scrollable list of glassmorphic cards:                   |
|    +---------------------------------------------------+    |
|    | Accent side border (4px Semantic Color)           |    |
|    | Country Name (e.g. Uganda / אוגנדה)                |    |
|    | Mapped Office / Source (e.g. NSC / מל"ל)          |    |
|    | Short Recommendation Text                         |    |
|    | Date / Update Timestamp                           |    |
|    +---------------------------------------------------+    |
+-------------------------------------------------------------+
| [Glassmorphic Bottom Sheet Detail Drawer]                   |
|  - Opens on card tap. Backdrop blur: 16px.                  |
|  - Show full detailed recommendations (HTML format support)|
|  - Details link (e.g. NSC website travel advisory)         |
|  - Direct action button to open official source advisory   |
+-------------------------------------------------------------+
```

---

## 3. Responsive Layout Guidelines

*   **Mobile breakpoint (< 600px):**
    *   Single-column layout using portrait orientation.
    *   Interactive elements (buttons, chips, cards) must maintain touch targets of at least `48px x 48px` to accommodate thumb reach.
    *   Bottom sheet operates as an overlay covering up to 85% height.
*   **Tablet/Desktop breakpoint (> 600px):**
    *   Responsive split pane or grid layout displaying cards and full detail side-by-side.

---

## 4. Bilingual Mirroring (RTL/LTR) Rules

*   **Logical Property Alignment:** All elements utilize CSS logical properties (e.g. `margin-inline-start`, `padding-inline-end`, `border-start-start-radius`) to ensure the layout flips natively.
*   **Hebrew Font Face:** Applies **Assistant** for all Hebrew text blocks.
*   **English/Numerical Font Face:** Applies **Outfit** for all English text and numeric values.

---

## 5. Micro-Animations & Interaction States

*   **Filter Chips Tap:** Active chip expands and lights up with a subtle primary border.
*   **Advisory Cards Hover/Tap:** Cards translate `4px` inline-start and increase backdrop saturation over a `150ms` cubic-bezier transition.
*   **Tap Active State:** Scales interactive buttons slightly down to `0.95x` to simulate a physical click.
*   **Skeleton Loader:** Cards display an animated HSL shimmer gradient moving from left to right while fetching data.
