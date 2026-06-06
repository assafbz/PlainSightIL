# UI/UX Specification: Alerting Feature (Issue #143)

## 📂 Stitch Screen References
- **Mockup URL**: [Stitch Alerts Feed Screen](https://stitch.withgoogle.com/projects/10303868738682079846/screens/5bd54713d74c4cabb84427b8e9ef9733)

---

## 1. Visual Theme & Theme Mode
To maintain the premium look defined in the PlainSightIL design system, the Alerts Feed uses the default **Slate Dark Mode**:
- **Background**: Solid `#0f131c` with Radial background gradients in secondary violet (`#571bc1` at 12% opacity) to provide atmospheric depth.
- **Card Styling (Glassmorphism)**: 
  - Background: `rgba(15, 23, 42, 0.75)`
  - Backdrop Blur: `ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0)`
  - Border: 1px outline using `rgba(255, 255, 255, 0.08)`
- **Status Accents**:
  - **Unread Alerts**: Border-inline-start colored in Primary Cyan (`#38bdf8`, 4px width) and an unread notification dot (`#38bdf8` circular indicator). Card has a soft cyan shadow glow.
  - **Read Alerts**: Border-inline-start colored in Neutral Muted Slate (`#3e484f`, 4px width) and no glow/dot.

---

## 2. Component Wireframe & Layout Architecture
```
+--------------------------------------------------------+
| [Header]                                               |
|  (Back Arrow)      Alerts / התראות    (Mark All Read)  |
+--------------------------------------------------------+
| [Alerts List Container] - Scrollable                   |
|                                                        |
|  +--------------------------------------------------+  |
|  | * [Icon] (Cyan Dot)                              |  |
|  | **Title (Bold)**                                 |  |
|  | Description (Assistant/Outfit text)              |  |
|  | [Badge] New Permits (14)                         |  |
|  | - - - - - - - - - - - - - - - - - - - - - - - -  |  |
|  | (Time-Ago) 10m ago                               |  |
|  +--------------------------------------------------+  |
|                                                        |
|  +--------------------------------------------------+  |
|  | [Icon] (Muted)                                   |  |
|  | **Title (Muted)**                                |  |
|  | Description (Read notification layout)           |  |
|  | - - - - - - - - - - - - - - - - - - - - - - - -  |  |
|  | (Time-Ago) 2h ago                                |  |
|  +--------------------------------------------------+  |
|                                                        |
+--------------------------------------------------------+
| [Footer] Floating Bottom Navigation Bar                |
| (Home Tab)    (Directory Tab)    (Alerts Tab - Active) |
+--------------------------------------------------------+
```

---

## 3. Responsive Layout Guidelines
- **Mobile Viewport (<600px)**:
  - Margins: 16px horizontal gutter.
  - Cards: Stacked vertically. Touch targets for swipe-to-dismiss actions and header buttons must satisfy at least 48x48px boundaries.
  - Unread count badge centered at bottom nav tab.
- **Tablet/Desktop Viewport (>=600px)**:
  - Max container width constrained to 800px.
  - Spacing: Margins expanded to 24px.
  - Dual columns: On tablet screens, a side-by-side view displays the Alert Feed on the left pane and the detailed metadata/subscription controls on the right pane.

---

## 4. UI/UX Interface Specs
- **Font Selection**:
  - English headings and counts: **Outfit** (weight: Bold / Semi-bold).
  - Hebrew details: **Assistant** (weight: Medium).
- **Directionality**:
  - Margins, paddings, and border offsets use `EdgeInsetsDirectional` and `BorderDirectional` to automatically mirror layout directions (RTL for Hebrew, LTR for English).
- **Empty State**:
  - Render a premium Glassmorphic panel containing a large muted bell icon, localized text ("You're all caught up!" / "הכל מעודכן!"), and a subtext description.

---

## 5. Motion & Micro-Animations
- **Hover/Tap States**:
  - Alert cards translate 4px inline-start and saturate background colors upon tap or hover over 150ms (`Duration Fast`).
- **Alert Status Changes**:
  - Transitioning from unread to read status uses a smooth cross-fade animation over 150ms to dim the cyan dot and animate the cyan glow away.
- **Swipe-to-Dismiss Transition**:
  - Swiping a notification card off-screen triggers a standard horizontal slide animation with a post-delete vertical list compaction over 300ms (`Duration Medium`) using a decelaration curve: `cubic-bezier(0.16, 1, 0.3, 1)`.

---

## 6. UX Layout Constraints & Hurdles
- **RTL Swiping Direction**:
  - Swipe gestures for dismiss/dismissible widgets must respect reading direction:
    - Hebrew: Swipe left-to-right (dismissing towards the right edge).
    - English: Swipe right-to-left (dismissing towards the left edge).
- **Bottom Navigation Overlay Offset**:
  - Since the application features a floating glassmorphic bottom bar, a bottom scroll padding of at least 80px must be appended to the scroll viewport to prevent alert items from being obscured.
