# PlainSightIL: Global UI/UX Design System & Styleguide

> [!NOTE]
> **Stitch Design Sync:**
> *   **Stitch Project Title:** Israel Open Data Explorer
> *   **Stitch Project ID:** `projects/10303868738682079846`
> *   **Stitch Web App:** [stitch.withgoogle.com](https://stitch.withgoogle.com)
> 
> The UI/UX style guide is defined and maintained inside Stitch. Changes to the design tokens, themes, or components should be updated in the Stitch project and synced.

This document defines the core design principles, typography, HSL color tokens, glassmorphism specs, bidirectional (RTL/LTR) layouts, and micro-interactions for the PlainSightIL application shell and visualization components, supporting both **Web CSS** and **Flutter/Dart** environments.

---

## 1. Design Philosophy

PlainSightIL is built to feel like a premium, native application on mobile and tablet devices. It prioritizes clarity, data readability, and visual comfort.

*   **Mobile-First Geometry**: Tailored for thumb-reach areas. The primary interactive elements are positioned in the bottom third of the screen (bottom sheet, dataset navigation tabs).
*   **Visual Premium ("Wow" Factor)**: Rejects standard flat web colors and boxy structures in favor of glassmorphism, dynamic glowing boundaries, custom SVG/Canvas visualizer charts, and rich HSL-based dark/light gradients.
*   **Logical Bi-directionality**: Standardizes layout mirroring natively through logical property parameters to support both Hebrew (RTL) and English (LTR) seamlessly.
*   **Cognitive Comfort**: Ensures high-density information is cleanly partitioned using glass panels, clear status badges, and subtle micro-animations that direct focus without clutter.

---

## 2. Color System & Semantic Tokens

To allow dynamic theme switching and absolute control over contrast, the styling system strictly uses HSL values. This allows easy opacity manipulation and runtime theme swaps.

### 2.1 Web CSS Color Palettes

#### Slate Dark Mode (Default)
```css
:root[data-theme="dark"] {
  /* Brand Colors */
  --brand-primary-hue: 195;     /* Cyan/Teal */
  --brand-secondary-hue: 260;   /* Violet */
  --brand-accent-hue: 38;       /* Amber */

  /* Background Palette */
  --color-bg-base: hsl(222, 47%, 7%);       /* Core background (#090d16) */
  --color-bg-surface: hsl(222, 40%, 11%);   /* Card/surface background (#111827) */
  --color-bg-overlay: hsl(222, 40%, 15%);   /* Popovers/modals */
  
  /* Glassmorphism Accents */
  --color-glass-bg: rgba(15, 23, 42, 0.75);
  --color-glass-border: rgba(255, 255, 255, 0.08);
  --color-glass-glow: rgba(56, 189, 248, 0.15); /* Primary cyan glow */

  /* Text Hierarchy */
  --color-text-primary: hsl(210, 40%, 98%);   /* Crisp white-blue */
  --color-text-secondary: hsl(215, 20%, 65%); /* Muted slate */
  --color-text-tertiary: hsl(215, 15%, 45%);  /* Dark muted slate */

  /* Semantic Feedback */
  --color-success: hsl(142, 70%, 45%);        /* Warm emerald green */
  --color-warning: hsl(38, 92%, 50%);         /* Warm amber */
  --color-danger: hsl(350, 89%, 60%);         /* Muted crimson */
}
```

#### Sleek Light Mode (Alternative)
```css
:root[data-theme="light"] {
  /* Background Palette */
  --color-bg-base: hsl(210, 40%, 96%);      /* Off-white ice blue (#f1f5f9) */
  --color-bg-surface: hsl(0, 0%, 100%);     /* Pure white */
  --color-bg-overlay: hsl(210, 20%, 98%);   /* Light grey overlay */

  /* Glassmorphism Accents */
  --color-glass-bg: rgba(255, 255, 255, 0.8);
  --color-glass-border: rgba(15, 23, 42, 0.06);
  --color-glass-glow: rgba(14, 165, 233, 0.1);

  /* Text Hierarchy */
  --color-text-primary: hsl(222, 47%, 11%);   /* Deep slate navy */
  --color-text-secondary: hsl(215, 25%, 40%); /* Medium slate grey */
  --color-text-tertiary: hsl(215, 16%, 57%);  /* Light slate grey */
}
```

### 2.2 Flutter (Dart) Color Palette Mappings
To translate the HSL color palette to native Flutter, compile brand values via the `HSLColor` class to build a reactive design token model:

```dart
class HslColorUtility {
  // Brand Hues
  static const double primaryHue = 195.0; // Cyan
  static const double secondaryHue = 260.0; // Violet
  static const double accentHue = 38.0; // Amber

  // Dark Palette Slate Values
  static Color darkBase() => HSLColor.fromAHSL(1.0, 222.0, 0.47, 0.07).toColor();
  static Color darkSurface() => HSLColor.fromAHSL(1.0, 222.0, 0.40, 0.11).toColor();
  static Color darkOverlay() => HSLColor.fromAHSL(1.0, 222.0, 0.40, 0.15).toColor();

  // Glass Elements
  static Color glassBackground({double opacity = 0.75}) => 
      HSLColor.fromAHSL(opacity, 222.0, 0.40, 0.09).toColor();
  static Color glassBorder({double opacity = 0.08}) => 
      Color.fromRGBO(255, 255, 255, opacity);
}
```

---

## 3. Typography & Font Scale

To guarantee a clean bilingual aesthetic, PlainSightIL maps typography to dedicated system typefaces tailored for English (Latin) and Hebrew (Semitic) characters.

*   **English/Fallback Font**: **Outfit** (Google Fonts) - A geometric, modern sans-serif.
*   **Hebrew Font**: **Assistant** (Google Fonts) - A clean, premium Hebrew font optimized for mobile screens.

### 3.1 Web CSS Mappings
```css
body {
  font-family: 'Outfit', 'Assistant', -apple-system, BlinkMacSystemFont, sans-serif;
  -webkit-font-smoothing: antialiased;
}
```

### 3.2 Flutter (Dart) Dynamic Font Selector
```dart
TextStyle getLocalizedStyle(BuildContext context, {required double fontSize, required FontWeight fontWeight}) {
  final isRtl = Directionality.of(context) == TextDirection.rtl;
  return isRtl 
    ? GoogleFonts.assistant(fontSize: fontSize, fontWeight: fontWeight)
    : GoogleFonts.outfit(fontSize: fontSize, fontWeight: fontWeight);
}
```

---

## 4. Bi-directional (RTL/LTR) Layout Grid

Rather than maintaining separate style declarations for English and Hebrew viewports, developers must use **Logical Properties** to handle directional mirroring automatically.

### 4.1 Web CSS Logical Rules
*   **No physical positioning (`left` / `right`)**: Use `inset-inline-start` / `inset-inline-end`.
*   **No physical margins/paddings (`margin-left` / `padding-right`)**: Use `margin-inline-start` / `padding-inline-end`.
*   **No physical border corners (`border-top-left-radius`)**: Use `border-start-start-radius`, etc.

### 4.2 Flutter (Dart) Directional Mirroring
Flutter provides native logical wrappers mirroring layouts automatically based on the active ambient `Directionality` widget. Use these classes strictly:

```dart
Widget buildDataCard(BuildContext context) {
  return Container(
    padding: const EdgeInsetsDirectional.only(
      start: 16.0,   // Left padding in LTR, right padding in RTL
      end: 24.0,     // Right padding in LTR, left padding in RTL
      top: 12.0,
      bottom: 12.0,
    ),
    decoration: BoxDecoration(
      border: BorderDirectional(
        start: BorderSide(color: HslColorUtility.darkSurface(), width: 4.0),
      ),
    ),
    child: Text('Card Content'.tr()),
  );
}
```

---

## 5. App Shell & Layout Geometry

The application UI consists of three primary zones: **App Header**, **Dynamic visualizer viewport (Canvas)**, and the **Interactive Bottom Sheet**.

### 5.1 Geometry Constants
*   **Header Height**: `64px` (`--header-height`)
*   **Bottom Sheet Collapsed Height**: `72px` (`--bottom-sheet-collapsed-height`)
*   **Touch Targets**: All interactive elements (buttons, navigation options, toggles) must satisfy a minimum boundary of `48px x 48px` to support thumb navigation.

---

## 6. Glassmorphism & Shadow Levels

Depth elevations are constructed using transparent containers paired with backdrop filtering.

### 6.1 Web CSS Glass Panel
```css
.glass-panel {
  background: var(--color-glass-bg);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid var(--color-glass-border);
  box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
}
```

### 6.2 Flutter (Dart) Glassmorphic Widget
Using Flutter's `BackdropFilter` inside a clipped rectangle container overlays and blurs the underlying canvas:

```dart
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const GlassmorphicCard({
    Key? key, 
    required this.child, 
    this.borderRadius = 16.0
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: HslColorUtility.glassBackground(),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: HslColorUtility.glassBorder(),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

---

## 7. Component Styling Specifications

### 7.1 Dynamic Bottom Sheet
*   **Collapsed State**: Sits at the bottom of the screen, showing the currently selected dataset metadata and search toggles (height: `72px`).
*   **Half-Expanded State**: Occupies 40% of the viewport height. Ideal for viewing search result items.
*   **Fully Expanded State**: Occupies 90% of the viewport height. Allows detailed viewing of single items (e.g., test certificates or history charts).
*   **Swipe/Drag Indicator**: A pill-like indicator at the top center of the drawer (`height: 5px`, `width: 40px`, `border-radius: 3px`) styled with a muted color.

### 7.2 Visualizations
When rendering charts, favor light vector custom drawings (SVGs or low-level `CustomPainter` commands in Flutter) over heavy web views or massive chart plugins to keep load times instantaneous.

---

## 8. Motion & Micro-Animations

### 8.1 Motion Constants
*   **Duration Fast**: `150ms` (toggles, hover states)
*   **Duration Medium**: `300ms` (drawer transitions, page cross-fades)
*   **Transition Curve (Bezier)**: `cubic-bezier(0.16, 1, 0.3, 1)` (smooth, premium deceleration curve).

### 8.2 Micro-Interactions
*   **Floating Action Buttons (FAB)**: Scale slightly down on touch active states (`scale(0.95)`) and rise/glow on hover.
*   **List Item Hover**: Translate slightly inline-start (+4px) and increase backdrop saturation.
