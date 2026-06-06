# PRD: Alerting Feature (Issue #143)

## 1. Executive Summary & Goals
The **Alerting Feature** aims to keep users actively engaged with government data updates by notifying them of relevant events. Instead of forcing users to manually check datasets for changes, this feature proactively alerts them when:
- **New dataset supported**: A new government open dataset becomes supported and visualized on the PlainSightIL platform.
- **New government dataset issued**: A completely new dataset is published by the government on `data.gov.il`.
- **New record in dataset found**: Monitored datasets receive new record ingestions during backend scraper cycles.

The goal is to increase user retention, daily active usage, and overall value of the application by providing a personalized, real-time feed of open-data events.

---

## 2. User Persona & Use Cases

### Primary Persona
- **Israeli Citizen / Civic Advocate**: Relies on data transparency (such as tracking local cellular tower permits or environmental warnings) and wants to be notified immediately of changes in their local area or of interest.

### Use Cases
- **UC-1 (Monitor Specific Dataset)**: A user living near a planned construction area wants to monitor the *Cellular Antennas Permits* dataset. They subscribe to it in the app. When the scraper runs and imports new permit records, the user receives an alert showing the new count.
- **UC-2 (Discover New Data)**: A researcher wants to know when PlainSightIL releases a new visualized dataset. When a new dataset (e.g. *Local Market Bonds*) is integrated, all users receive an alert about the new feature.
- **UC-3 (Government Data Discovery)**: A civic advocate wants to know whenever the government publishes a completely new open dataset on `data.gov.il` (even if it's not yet visualized on PlainSightIL). During the metadata sync, a new package is detected on CKAN. All users receive a notification about the new dataset discovery.
- **UC-4 (Manage Alert Feed)**: A user opens their "Alerts" tab, reviews a list of unread notifications, reads them, marks them as read, or deletes obsolete alerts to keep their workspace clean.

---

## 3. Functional Requirements

### Subscription Management
- **FR-01 (User Subscriptions)**: Authenticated users must be able to toggle monitoring subscriptions on a per-dataset basis.
  - Subscriptions must be persisted in a dedicated Firestore root collection `/subscriptions` with a composite document ID: `${userId}_${datasetId}`.
  - Toggling subscription is instantly updated in Firestore and dynamically reflected on the dataset's detail screen.
- **FR-02 (Subscription UI)**: A sleek subscription toggle button (bell icon or switch) must be added to all dataset page headers. If a user is not signed in, tapping the button prompts them to sign in.

### Notification Triggers (Backend)
- **FR-03 (New Visualizer Supported Alert)**: During CKAN metadata sync (`metadata_scraper`), when a dataset's `isSupported` status transitions to `true` (indicating a newly supported dataset has been deployed), a broadcast alert is generated.
  - A copy of the alert document is created in every registered user's private alerts subcollection.
- **FR-04 (New Government Dataset Alert)**: During CKAN metadata sync (`metadata_scraper`), when a completely new dataset metadata record is created (meaning a new dataset was published on `data.gov.il` by the government), a broadcast alert is generated.
  - A copy of the alert document is created in every registered user's private alerts subcollection.
- **FR-05 (New Records Alert)**: During backend scraper runs, if a scraper completes successfully and registers new ingested records (`count > 0`):
  - The function queries `/subscriptions` for users monitoring that `datasetId`.
  - For each subscribed user, a `new_records` alert is written to their `/users/{userId}/alerts/` subcollection.
  - **First Sync Exclusion**: No alerts must be generated if this is the first successful sync of the dataset (i.e. there were 0 records in the database prior to the sync).

### User Notification Feed (Client UI)
- **FR-06 (Alerts View)**: The third tab of the floating navigation bar must render a premium `AlertsPage` replacing the current "Coming Soon" screen.
  - The screen must require user sign-in. If the user is unauthenticated, render a clean, glassmorphic sign-in call-to-action (CTA).
  - If authenticated, display a list of alerts loaded from Firestore `/users/{userId}/alerts` sorted chronologically (latest first).
  - Unread alerts must have a distinct visual glow or badge.
  - Support swipe-to-dismiss (delete alert from Firestore) and tap to mark as read.
  - Provide a "Mark all as read" button in the top header.
- **FR-07 (Alert Interactivity)**: Tapping an alert item must:
  - Mark it as read in Firestore.
  - Instantly navigate the user directly to the corresponding dataset's detail view.
- **FR-08 (Unread Count Badge)**: Render a dynamic red badge with the count of unread alerts on the bottom navigation bar's notification bell icon and on the navigation drawer's alert option.

---

## 4. Non-Functional Requirements & UX Guidelines
- **NFR-01 (Aesthetics)**: Alerts cards must follow the global PlainSightIL design system: HSL-based slate colors in dark mode, glassmorphism background filters, border glows, and custom typography (Outfit for English, Assistant for Hebrew).
- **NFR-02 (Performance)**: Real-time queries must be limited to the 100 most recent alerts using firestore pagination to prevent high memory usage. The interface should render updates and mark-read responses in under 100ms.
- **NFR-03 (Bi-directionality)**: Layouts must mirror natively using logical property classes (LTR for English, RTL for Hebrew).
- **NFR-04 (Security)**: The `/users/{userId}/alerts/{alertId}` subcollection and `/subscriptions` documents must be fully secured using Firestore Security Rules, preventing unauthorized cross-user reading or writing.

---

## 5. Exclusions (Out of Scope)
- **Email / SMS / Push Notifications**: Native mobile push notifications (FCM) or email digests are excluded from the initial version. Alerts are strictly in-app only, displayed via the user's private feed.
- **Custom Alert Rules**: Users cannot define custom filters (e.g. "Only notify me if the cellular antenna is within 1km"). All updates to subscribed datasets trigger a standard alert.

---

## 6. Open Questions
*None. Technical design covers all areas.*

---

## 7. Product Obstacles & Scope Hurdles
- **Simultaneous Scraper Runs**: Since scrapers run concurrently, multiple alert documents could be created in quick succession. We must ensure the client UI can handle rapid real-time list updates without flickering or jumpy scrolling.
- **Mock User Compatibility**: For local testing and development where authentication is mocked or bypassed, the alert state notifier must support mock-user configurations gracefully.
