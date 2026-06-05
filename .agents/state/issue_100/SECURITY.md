# Security Audit Report: Save User Language Selection (Issue #100)

## 1. Threat Modeling & Attack Surfaces
- **Attack Surface**: Device local storage (`SharedPreferences` on native, `window.localStorage` on Web).
- **Threat Vectors**:
  - Malicious tampering of the persisted `'locale'` storage value (e.g. inject arbitrary strings, scripts, or path characters to cause app crashes or layout rendering failures).

## 2. Input Validation Specifications
- **Sanitization & Validation**:
  - The value retrieved from local storage must be checked before application:
    `if (savedLocale == 'en' || savedLocale == 'he') { ... }`
  - Any other value must be rejected and ignored, gracefully falling back to the default `'en'` value.

## 3. Database & Rules Configurations
- **Database Scope**: Out of scope. This feature is entirely client-side and does not read or write from Cloud Firestore. No database rule modifications are needed.

## 4. Audit Findings & Remediations
- **FINDING-01 (Severity: Low)**: Missing validation of the stored locale string could lead to UI failures.
  - *Remediation*: The setter `setLocale(String newLocale)` and the startup loader `_loadLocale()` must validate the locale string against the allowlist of supported locales (`'en'`, `'he'`).
- **Approval Status**: APPROVED

## 5. Security Hurdles & Threat Risks
- No packages or external HTTP dependencies are introduced, eliminating third-party supply-chain risks.
