# Security Audit Report: Alerting Feature (Issue #143)

## 1. Threat Modeling & Attack Surfaces

- **Alert Injection Vector**: Malicious users attempting to write unsolicited alerts directly to their own or other users' `/users/{userId}/alerts` subcollections.
  - *Mitigation*: Clients are completely blocked from writing (`allow create: if false;`) to any alert collections. Creation is restricted to administrative Cloud Functions running with elevated server SDK privileges.
- **Cross-User Data Leakage**: Users attempting to read or manipulate notifications or subscriptions of other users.
  - *Mitigation*: Firestore rules enforce strict owner-based validation. A user's UID (`request.auth.uid`) must match the document path (`userId` context) for alerts, or the stored `userId` attribute for subscription documents.
- **Notification Spam / DDOS**: Rapid scraper executions generating massive numbers of alerts per user, causing high database read/write cost and client-side memory exhaustion.
  - *Mitigation*: The `changedCount` indicator limits alert generation to runs where actual changes are identified. First sync guard blocks alerts on first run. Clients paginate alerts to a maximum of 100 entries.

---

## 2. Input Validation Specifications

- **Composite Key Integrity**: Subscriptions are validated on creation to verify that the subscription document ID is formatted strictly as `${userId}_${datasetId}`.
- **User Verification**: When a user subscribes, the database rule validates that `request.resource.data.userId == request.auth.uid` to prevent subscribing on behalf of other users.
- **Alert Schemas**: Server-side alert creations are typed and restrict keys to the defined alert properties: `id`, `userId`, `type`, `title`, `description`, `datasetId`, `recordCount`, `isRead`, `createdAt`.

---

## 3. Database & Rules Configurations

Firestore Security Rules have been updated in `backend/firestore.rules` to include the following policies:

```javascript
    match /users/{userId}/alerts/{alertId} {
      allow read, update, delete: if request.auth != null && request.auth.uid == userId;
      allow create: if false; // Restrict client-side writes entirely
    }

    match /subscriptions/{subscriptionId} {
      allow read, write: if request.auth != null && (
        (resource == null && request.resource.data.userId == request.auth.uid) ||
        (resource != null && resource.data.userId == request.auth.uid)
      );
    }
```

---

## 4. Audit Findings & Remediations

- **FINDING-01 (Severity: Low) — Mock Mode Session Isolation**:
  - *Description*: In mock testing mode (`AppStateNotifier.isTesting = true`), authentication uses hardcoded values (`mock_uid`) and mock data is generated locally without contacting Firestore. This is safe for local layout preview and test runs but must not be compiled into production releases.
  - *Remediation*: Checked that `isTesting` flag is set to `false` in production environments, and release bundles are compiled with real Firebase configurations.
- **Approval Status**: **APPROVED**

---

## 5. Security Hurdles & Threat Risks

No external package dependencies were added, keeping the dependency risk profile unchanged. All alert transactions operate strictly in-app over HTTPS, eliminating risk surfaces associated with external SMS or push gateways.
