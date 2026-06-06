# UI/UX Specification: Redesigned Auth Flow (One-Page Experience)

This document defines the visual layout, typographic hierarchy, responsive guidelines, and animation specifications for the redesigned unified login/signup screen.

## 📂 Stitch Screen References
- **Stitch Project ID**: `projects/10303868738682079846`
- **Login screen mockup**: [Login - PlainSight IL](https://stitch.withgoogle.com/projects/10303868738682079846/screens/af74b81ef55f423f8868c7f48d22c3a3)
- **Sign Up screen mockup**: [Sign Up - PlainSight IL](https://stitch.withgoogle.com/projects/10303868738682079846/screens/d7cd372f80f14396a9ba25bbe64443df)
   - Title: "Create Account"
   - Prompt: "Create a stunning Sign Up screen for PlainSight IL... Primary Action: A prominent 'Sign up with Google' button. Trust Signals: 'SECURE 256-BIT ENCRYPTION' badge..."

---

## 1. Visual Theme & Theme Mode

To deliver an elite "wow" factor, the unified page uses **Slate Dark Mode** by default with dynamic glassmorphism and ambient neon depth:
- **Base Background**: Solid slate navy (`#0F131C`) layered with a cybernetic grid pattern at 10% opacity.
- **Ambient Depth (Glow Orbs)**:
  - *Primary Teal Orb*: Top-left quadrant. Circular gradient (`#8ED5FF` at 12% opacity), blurred using an 80px radius. Slow hover movement tracks cursor.
  - *Secondary Violet Orb*: Bottom-right quadrant. Circular gradient (`#D0BCFF` at 12% opacity), blurred using an 80px radius. Moves inversely to cursor.
- **Unified Auth Card (Glassmorphic)**:
  - Frosted glass style using `AppColors.glassBg` (`rgba(15, 23, 42, 0.75)`).
  - High-diffusion backdrop blur: `sigmaX: 16.0, sigmaY: 16.0`.
  - Edge border: 1px thin stroke (`rgba(255, 255, 255, 0.08)`).
  - Rounded corners: 32px (`BorderRadius.circular(32)`).

---

## 2. Component Wireframe & Layout Architecture

```
+-------------------------------------------------------------+
| [Language Switcher]  (Top Right/Left floating glass pill)   |
+-------------------------------------------------------------+
|                                                             |
|   +-----------------------------------------------------+   |
|   |                  [Rotating Logo]                    |   |
|   |                   PlainSight IL                     |   |
|   |         Unlock the transparency of civic data       |   |
|   +-----------------------------------------------------+   |
|                                                             |
|   +------------------[ Unified Card ]-------------------+   |
|   |                                                     |   |
|   |   +------------------[ Tab Switcher ]-----------+   |   |
|   |   | [  Sign In (Active) ]   [     Sign Up     ] |   |   |
|   |   +---------------------------------------------+   |   |
|   |                                                     |   |
|   |   [ Animated Content Switcher (Cross-Fade & Size) ] |   |
|   |                                                     |   |
|   |   - Title: "Welcome Back" / "Create Account"        |   |
|   |   - Subtitle: "Secure Authentication"               |   |
|   |   - Button: Premium Google Sign In / Sign Up        |   |
|   |   - Divider: --- PROTECTED BY SSL ---               |   |
|   |   - Footer: Info Box / Terms Disclaimer             |   |
|   |                                                     |   |
|   +-----------------------------------------------------+   |
|                                                             |
|   [Continue as Guest] (Muted link with hover underline)    |
|                                                             |
+-------------------------------------------------------------+
```

---

## 3. Responsive Layout Guidelines

- **Mobile Viewport (<600px)**:
  - Gutter: 24px horizontal margin.
  - Card width: Constrained to `double.infinity` with max-width of 420px.
  - Target sizes: 48x48px boundaries for language toggles and the guest bypass link.
- **Tablet/Desktop Viewport (>=600px)**:
  - Card centered vertically and horizontally.
  - Max width constrained to 420px to ensure card content does not stretch unnaturally.
  - Grid Paper scaling matches viewport size.

---

## 4. UI/UX Interface Specs

### 4.1 Typography Hierarchy
- **Primary Brand Font**: **Outfit** (Latin glyphs and numbers) - heavy tracking (-0.5px) and weights (ExtraBold).
- **Secondary Hebrew Font**: **Assistant** (Semitic glyphs) - optimized for RTL legibility.
- **Title (Welcome Back/Create Account)**: Font size 20px, Semi-Bold.
- **Google Button Label**: Font size 16px, Semi-Bold.
- **SSL Badge & Disclaimers**: Font size 12px / 10px, Medium.

### 4.2 Tab Segmented Switcher
- Designed as a single glass row with an inner sliding active selector:
  - Outer background: Deep slate navy (`#090d16` at 50% opacity), rounded pill.
  - Inner sliding capsule: Solid cyan glass/gradient (`rgba(56, 189, 248, 0.12)`), bounded by a thin outline. Slides using `AnimatedAlign`.

---

## 5. Micro-Animations & Interaction States

To create an experience that feels alive:
- **Tab Swapping**:
  - Sliding active indicator uses `AnimatedAlign` with `duration: const Duration(milliseconds: 300)` and curve `Curves.easeOutCubic`.
  - Color transition of active text (Teal -> Muted Slate) fades over 150ms.
- **Card Content Cross-Fade**:
  - Main contents inside the glass card animate via `AnimatedSwitcher` containing a combined `FadeTransition` and `SizeTransition` to change height dynamically without jarring jumps.
- **Brand Logo Rotation**:
  - Interactive hover rotation: Logo rotates slightly by 3 degrees (`3 / 360` turns) over 300ms using `AnimatedRotation` when hovered.
- **Google Buttons (Wow Factor)**:
  - Theme-compliant styling: Both buttons use a premium dark glass background (`AppColors.glassBg`) and light text (`Colors.white`) to align with the night-mode theme. No solid white backgrounds.
  - Scale transition: Shrinks slightly on touch down to `0.97` using `ScaleTransition` or direct gesture builder to feel tactile.
  - Custom border glow: Hovering over the button triggers a subtle radial cyan/violet glow border.

---

## 6. UX Layout Constraints & Hurdles

- **RTL Language Mirroring**:
  - The tab switcher must swap the direction of the sliding pill correctly:
    - Hebrew (RTL): Tab 1 (Login) is on the right, Tab 2 (Signup) is on the left.
    - English (LTR): Tab 1 (Login) is on the left, Tab 2 (Signup) is on the right.
  - Use `AlignmentDirectional` (`centerStart` and `centerEnd`) to ensure native mirroring without hardcoding coordinate logic.
