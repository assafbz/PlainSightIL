---
name: PlainSight IL
colors:
  surface: '#0f131c'
  surface-dim: '#0f131c'
  surface-bright: '#353943'
  surface-container-lowest: '#0a0e17'
  surface-container-low: '#181b25'
  surface-container: '#1c1f29'
  surface-container-high: '#262a34'
  surface-container-highest: '#31353f'
  on-surface: '#dfe2ef'
  on-surface-variant: '#bdc8d1'
  inverse-surface: '#dfe2ef'
  inverse-on-surface: '#2c303a'
  outline: '#87929a'
  outline-variant: '#3e484f'
  surface-tint: '#7bd0ff'
  primary: '#8ed5ff'
  on-primary: '#00354a'
  primary-container: '#38bdf8'
  on-primary-container: '#004965'
  inverse-primary: '#00668a'
  secondary: '#d0bcff'
  on-secondary: '#3c0091'
  secondary-container: '#571bc1'
  on-secondary-container: '#c4abff'
  tertiary: '#ffc42f'
  on-tertiary: '#402d00'
  tertiary-container: '#e1a800'
  on-tertiary-container: '#584000'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c4e7ff'
  primary-fixed-dim: '#7bd0ff'
  on-primary-fixed: '#001e2c'
  on-primary-fixed-variant: '#004c69'
  secondary-fixed: '#e9ddff'
  secondary-fixed-dim: '#d0bcff'
  on-secondary-fixed: '#23005c'
  on-secondary-fixed-variant: '#5516be'
  tertiary-fixed: '#ffdf9f'
  tertiary-fixed-dim: '#f9bd22'
  on-tertiary-fixed: '#261a00'
  on-tertiary-fixed-variant: '#5c4300'
  background: '#0f131c'
  on-background: '#dfe2ef'
  surface-variant: '#31353f'
  success: '#34d399'
  warning: '#f59e0b'
  danger: '#f43f5e'
  info: '#0ea5e9'
  glass-bg: rgba(15, 23, 42, 0.75)
  glass-border: rgba(255, 255, 255, 0.08)
  glass-glow: rgba(56, 189, 248, 0.15)
typography:
  headline-lg:
    fontFamily: Outfit
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Outfit
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Outfit
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: '0'
  body-sm:
    fontFamily: Outfit
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-xs:
    fontFamily: Outfit
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  header-height: 64px
  bottom-sheet-collapsed: 72px
  touch-target: 48px
  gutter: 1rem
  margin-mobile: 1.5rem
---

## Brand & Style

The brand personality is **authoritative yet approachable**, functioning as a premium lens through which complex civic data becomes clear and actionable. It evokes a sense of "technological transparency"—combining the reliability of a government utility with the sleek, high-fidelity experience of a modern fintech app.

The design system adopts a **Premium Glassmorphism** style. This approach uses depth, translucency, and light to organize high-density information without overwhelming the user. By utilizing frosted glass textures and vibrant background blurs, the UI feels layered and architectural. 

Key stylistic pillars include:
- **Atmospheric Depth:** Multi-layered surfaces that stack logically, utilizing backdrop filters (16px blur) to maintain context of the underlying data visualizations.
- **Luminous Boundaries:** Subtle "glow" borders that define edges in dark mode, reflecting the cyan and violet brand hues.
- **Data-Centricity:** Every visual choice—from the geometric font to the HSL-based color tokens—is designed to prioritize legibility and rapid information scanning.

## Colors

The system uses an **HSL-first logic** to allow for dynamic opacity adjustments and smooth theme transitions. The default palette is **Slate Dark Mode**, which avoids pure black to reduce eye strain during deep data analysis.

- **Primary (Cyan/Teal):** Used for interactive states, primary action glows, and focus indicators.
- **Secondary (Violet):** Used for accenting different datasets and creating depth in gradients.
- **Neutral (Slate):** The foundational scale for surfaces, text hierarchy, and structural borders.

Colors are applied using logical CSS properties. Glass effects are achieved by pairing the `glass-bg` token with a `backdrop-filter: blur(16px)`. Semantic colors (success, warning, danger) are reserved for data status indicators, such as radiation permit validity or water level thresholds.

## Typography

This design system employs a bilingual typographic strategy. **Outfit** is the primary typeface for English text and all numerical data, providing a modern, geometric feel that excels in technical contexts. For Hebrew (RTL) content, the system defaults to **Assistant**, a premium sans-serif optimized for mobile legibility.

### Hierarchy Rules:
- **Headlines:** Bold and tight-tracked to create a strong visual anchor for screen titles.
- **Body:** Standardized at 16px for optimal reading on mobile devices.
- **Data Labels:** Use the `label-xs` token with semi-bold weighting and increased letter spacing to ensure small-scale metadata remains legible and distinct.
- **Bilingual Support:** All typography must use CSS logical properties. Font-family stacks must prioritize the specific language font based on the `dir` attribute of the container.

## Layout & Spacing

The layout is **Mobile-First** and adheres to a "Thumb-Reach Geometry." Interactive elements are concentrated in the bottom third of the viewport, primarily housed within the dynamic Bottom Sheet.

### Logical Layout Model:
- **Directionality:** All spacing (margins, padding, borders) is defined via **CSS Logical Properties** (`margin-inline-start`, `padding-block-end`) to ensure the UI mirrors perfectly between Hebrew (RTL) and English (LTR).
- **The Bottom Sheet:** The core interaction hub. It transitions between three heights: Collapsed (72px), Half (40vh), and Full (90vh).
- **Viewport Pane:** The area between the header and the collapsed bottom sheet is reserved for primary visualizers (Leaflet maps or SVG charts).
- **Rhythm:** A 4px/8px base grid drives all spacing units to ensure mathematical harmony across components.

## Elevation & Depth

Visual hierarchy is established through **Tonal Layering** and **Glassmorphism**, rather than traditional heavy shadows. Depth is used to communicate the "stack" of the application.

- **Level 1 (Base):** The `color-bg-base` slate background. Used for the main canvas or map layer.
- **Level 2 (Surface):** Tonal layers for interactive list items and cards. Use subtle 1px glass borders to define boundaries.
- **Level 3 (Overlay):** Floating Action Buttons (FABs) and Headers. These use `Elevation Medium` shadows with a slight tint of the primary cyan to appear as if they are floating.
- **Level 4 (System):** The Bottom Sheet and Modals. These use high-diffusion shadows (`0 12px 40px -4px rgba(0,0,0,0.5)`) and maximum backdrop blur to completely isolate the user's focus.

**Interaction Hint:** On touch, elevated elements should scale slightly down (0.95x) to provide tactile feedback.

## Shapes

The shape language is **Rounded**, balancing modern aesthetics with a friendly, approachable feel. 

- **Containers:** Standard cards and glass panels use a 0.5rem (8px) radius.
- **Logical Radii:** Corner radii must be defined using logical properties (e.g., `border-start-start-radius`) to ensure the "outer" curve of a card stays on the correct side when switching from LTR to RTL.
- **Pill Elements:** Drag handles on bottom sheets and status badges use the `rounded-xl` (1.5rem) or full pill radius to distinguish them from structural layout containers.

## Components

### Buttons & FABs
- **Primary FAB:** Circular (48px min), cyan glow background, `Elevation Medium`. Scales on press.
- **Action Buttons:** Glass-based with `color-glass-border`. Text must maintain 4.5:1 contrast.

### Dynamic Bottom Sheet
- **Handle:** A 40x5px pill centered at the top.
- **Transitions:** Must use the "Ultra-premium" curve `cubic-bezier(0.16, 1, 0.3, 1)` over 300ms.
- **Content:** Information is partitioned into sections using logical padding and thin glass separators.

### Data Cards
- **Visual:** Glass panel with a 4px logical border-inline-start utilizing a semantic color (e.g., success green for active permits).
- **Interaction:** On hover/tap, cards translate 4px inline-start and increase backdrop saturation.

### Input Fields
- **Search:** Integrated into the bottom sheet. Soft-rounded, background using `color-bg-overlay`, with a high-contrast focus ring using the primary cyan.

### SVG Visualizers
- Charts and gauges should use HSL-based gradients. 
- **Gauges:** Concentric circles with `stroke-dasharray`. 
- **Tooltips:** Glassmorphic overlays that appear relative to the data point with a 150ms fade.