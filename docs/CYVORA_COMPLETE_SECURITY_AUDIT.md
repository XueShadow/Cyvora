# Cyvora Complete Security Audit

**Scope:** Source-level review and safe local validation on
`security/complete-production-hardening`, based on `83fba3c` plus the current
uncommitted remediation changes.
**Production access:** None. No production credentials, database operations,
deployments, or provider requests were performed.

## Executive summary

No confirmed exploitable vulnerability was identified in the reviewed source.
This is not a penetration test or a certification of deployed systems. The
Android release trust boundary and notification queue reliability concerns
identified in the earlier audit have source-level remediations on this branch.
Notification scan idempotency depends on migration
`202611170005_notification_scan_idempotency.sql`, which has not been executed
against PostgreSQL.

Local Flutter analysis, 66 Flutter tests, 94 Supabase Node tests, 15 Android
release policy tests, and an Android debug APK build passed. These checks do
not verify SQL semantics, live Edge Function/provider behavior, GitHub owner
settings, or Android device/OEM lifecycle behavior.

## Architecture map

```text
Flutter mobile client
  ├─ Supabase Auth and MFA
  ├─ DashboardRepository -> Supabase data and Edge Functions
  ├─ deterministic scan UI, history, alerts, Family Protection, settings
  └─ Android notification listener
       └─ consented Keystore-encrypted queue -> user review/retry -> scan

Supabase Edge Functions
  ├─ scam-intelligence -> deterministic analysis, optional AI/URL checks,
  │                       quotas, persistence, notification idempotency
  └─ family-invitations -> authenticated invite lifecycle and RPC calls

Supabase PostgreSQL
  └─ migrations -> application data, RLS, RPCs, quotas, retention,
                   scan-result replay state

Laravel
  └─ separate scaffold; no active Cyvora client/API contract was verified

GitHub Actions
  ├─ CI -> Flutter checks/build and backend Node tests
  └─ Android release -> ref validation, gated signing, draft publication
```

The existing Flutter + Supabase architecture is retained. The Android
notification service does not replace the default SMS application. Notification
analysis remains a user-reviewed flow rather than automatic background
analysis.

## Current findings

| ID | Status | Severity | Confidence | Finding and disposition |
|---|---|---:|---:|---|
| F-01 | REMEDIATED IN SOURCE; OWNER SETTINGS UNVERIFIED | High potential impact | 8/10 | Release tags are checked against the default branch; signing and publishing use separate GitHub Environments; permissions are narrowed and releases remain drafts. Repository rules, Environment reviewers, restrictions, and secret placement still require owner verification. |
| F-02 | REMEDIATED IN SOURCE; SQL NOT EXECUTED | Low reliability | 9/10 | A notification could be analyzed twice after a client interruption between successful analysis and local completion marking. The client now carries a stable revision key, and the Edge Function reserves/replays a user-scoped request through an atomic RPC. The new migration and runtime concurrency behavior are unverified. |
| F-03 | OPEN PRIVACY LIMITATION | Medium privacy | 8/10 | Optional AI inputs are minimized server-side (email, Philippine mobile numbers, short numeric codes, and URL secrets), but this is heuristic and not on-device redaction. Other identifiers or secrets may remain. Keep optional third-party analysis opt-in and verify redaction with representative tests. |
| F-04 | NOT VERIFIED | Medium assurance | 9/10 | RLS, cross-account/family isolation, and RPC grants were reviewed in source, but PostgreSQL/pgTAP suites were not run. |
| F-05 | NOT VERIFIED | Medium operational | 9/10 | Provider authentication, model availability, billing, and live failure behavior were not tested. Request quotas do not cap provider spend. |
| F-06 | NOT VERIFIED | Low assurance | 9/10 | Android Keystore encryption, retention expiry, permission revocation, key-loss recovery, process death, and OEM behavior have not been tested on devices. |
| F-07 | OPEN QUALITY GAP | Medium confidence | 9/10 | Scam metrics use a 14-example synthetic fixture; they are not evidence of real-world precision, recall, F1, or false-positive rates. |

No confirmed exploitable vulnerability remains in this source-only review.
The open items above are privacy, deployment, validation, and quality risks;
they are not represented as proven exploits.

## Authentication and authorization

- Flutter uses Supabase Auth and the publishable key; no service-role key is
  included in the client.
- Protected Edge Function paths validate the bearer token and MFA state in
  source. Their deployed revisions and live authorization behavior were not
  checked.
- SQL migrations define RLS and restrict privileged RPC execution. The
  prepared SQL suite covers scan access, family isolation, cross-account
  writes, unauthorized RPCs, invitation expiry/reuse, deletion, and quota
  behavior; it has not been run.
- Family invitation creation/acceptance uses server-side RPCs, hashed tokens,
  expiration, and verified-email checks in source. Concurrent invitation
  behavior requires a PostgreSQL test.

## Database, Edge Functions, and AI

- Migrations `202611170001`–`202611170005` and the matching Edge Function
  calls are repository code only. No migration ledger was rechecked during
  this work, and no deployment is claimed.
- The new notification idempotency migration uses user/request keys,
  HMAC-based content fingerprints, a five-minute row-locked lease, a
  service-role-only reservation/record/release path, atomic scan persistence,
  deleted-history tombstones, and a 35-day cleanup job. The migration fails
  if `pg_cron` is unavailable so retention cannot be silently assumed.
- A provider call can still be repeated if a process crashes after the provider
  responds but before database completion and the lease expires. Provider-side
  idempotency was not established.
- AI is optional and selected through server configuration. The source
  validates structured responses, bounds calls, limits fallback routing, and
  applies request-count controls. No live credentials or provider requests
  were used. Monetary spend controls must be configured with each provider.
- URL reputation integrations reject private/reserved destinations and avoid
  fetching the submitted page in the reviewed source. Live DNS/network
  behavior was not tested.

## Notification privacy and reliability

- Android notification previews are collected after local consent, stored in
  app-private AES/GCM-encrypted storage backed by Android Keystore, and subject
  to 1/7/30-day retention settings and user clearing controls.
- Queue items are preserved after analysis failures and can be retried.
  Successful local completion is durably marked before cleanup.
- A revision-specific idempotency key is generated from Android notification
  identity/time metadata; message contents are not used in that key. The server
  reserves before scan quota and atomically persists/replays completed results.
- The Flutter/native source and tests do not prove device hardware behavior.
  No notification contents should be logged.
- Notification monitoring is not automatic analysis. Users review and submit
  queued notifications. Optional external analysis requires user selection;
  heuristic minimization is applied before optional AI provider submission,
  but is not a guarantee of complete de-identification.

## Laravel, CI/CD, and platform notes

- Laravel remains in the repository. The inspected scaffold has no verified
  Cyvora API contract or Flutter integration; PHP/Composer tests were blocked.
- Release workflow source verifies stable-tag ancestry, uses the
  `android-signing` and `android-publish` Environments, and publishes drafts.
  The repository owner must configure required reviewers, environment
  deployment restrictions, protected `v*` tags, branch rules, and signing
  secrets. No GitHub settings were changed.
- iOS/Xcode, physical Android devices, and OEM-specific behavior were not
  available in this Windows validation environment. Existing Android/iOS
  identifiers differ and were not changed.

## Test results and limits

| Check | Result |
|---|---|
| Flutter analyze | PASS |
| Flutter tests | PASS — 66 |
| Supabase Node tests | PASS — 94; mocked/source-contract tests, not PostgreSQL |
| Android release policy tests | PASS — 15 |
| Android debug APK | PASS; no device install |
| PostgreSQL migration/RLS/idempotency pgTAP | PREPARED — 13 security-boundary assertions and 14 idempotency assertions; NOT RUN |
| Deno, PHP/Composer, live providers, iOS/device tests | NOT RUN / UNAVAILABLE |
| Dependency advisory scans | NOT RUN; relevant scanner/runtime tools unavailable |

See [staging validation](CYVORA_STAGING_VALIDATION.md) for safe next steps,
[remediation report](CYVORA_REMEDIATION_REPORT.md) for changed behavior, and
[final checklist](CYVORA_FINAL_PRODUCTION_CHECKLIST.md) for release gates.
