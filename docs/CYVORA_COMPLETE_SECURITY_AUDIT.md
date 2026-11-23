# Cyvora Complete Security Audit

**Scope:** Source-level review and safe local validation on
`security/complete-production-hardening` at
`392231280bbfaf1dc09096a77ebe4cbf0542e0bd`, relative to `83fba3c`.
The source implementation was previously validated at `659b79d`; this pass
adds only a synthetic evaluation fixture and documentation. At audit start,
tracked files were clean. The untracked `security-hardening-review.patch`
was identified as a patch containing paths from the branch diff and preserved
without applying, deleting, or modifying it.
**Production access:** None. No production credentials, database operations,
deployments, or provider requests were performed.

> **Integration update (2026-11-23):** This audit is a snapshot of the
> `security/complete-production-hardening` branch and does not include changes
> unique to `fix/mlkit-release-crash`. The integrated branch retains mandatory
> MFA enrollment for privileged users, the `super_admin` moderation role, and
> the implemented Laravel Super Admin panel. The security-branch MFA
> regression is recorded as F-09 below and is not carried into the integration.

## Executive summary

An independent security review identified no confirmed exploitable
vulnerability in the reviewed source or workflow code.
This is not a penetration test or a certification of deployed systems. The
Android release trust boundary and notification queue reliability concerns
identified in the earlier audit have source-level remediations on this branch.
Notification idempotency migrations through
`202611170007_notification_scan_reservation_initial_lease.sql` were executed
against disposable local Supabase PostgreSQL during follow-up validation.

Local Flutter analysis, 66 Flutter tests, 96 Supabase Node tests, 15 Android
release-policy tests, an Android debug APK build, 27 pgTAP assertions, and 7
separate-connection notification-reservation checks passed. All 24 repository
migrations through `202611170007` were applied to a fresh disposable Supabase
PostgreSQL 17.11.0.018 container. This used direct `psql` with test-only
Auth/Storage helpers, not full Supabase CLI orchestration or hosted staging.
The three latest migrations were also reapplied successfully, and catalog
checks found RLS enabled on all 31 public tables and no public
`SECURITY DEFINER` functions lacking a fixed `search_path`. The expanded synthetic scam fixture
passed on 26 examples, including six paired categories; its perfect result is
not a real-world performance estimate. Hosted Edge Function and provider
behavior, GitHub owner settings, and Android device/OEM lifecycle remain
unverified.

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

Laravel Super Admin panel
  └─ separate server-rendered admin client on the fix/integration branch;
     excluded from this security-branch source snapshot

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
| F-02 | LOCAL DATABASE TESTS PASS; HOSTED STAGING UNVERIFIED | Low reliability | 9/10 | A notification could be analyzed twice after a client interruption between successful analysis and local completion marking. The stable revision key and reservation/replay RPC passed 14 pgTAP assertions plus 7 independent-session checks locally. Deployed behavior remains unverified. |
| F-03 | OPEN PRIVACY LIMITATION | Medium privacy | 8/10 | Optional AI inputs are minimized server-side (email, Philippine mobile numbers, short numeric codes, and URL secrets), but this is heuristic and not on-device redaction. Other identifiers or secrets may remain. Keep optional third-party analysis opt-in and verify redaction with representative tests. |
| F-04 | LOCAL DATABASE TESTS PASS; HOSTED STAGING UNVERIFIED | Medium assurance | 9/10 | RLS, cross-account/family isolation, and RPC grants passed the 13-assertion pgTAP security-boundary suite; notification ownership isolation and service-role RPC restrictions also passed separate-session local checks. Hosted deployment state and Edge Function authorization remain unverified. |
| F-05 | NOT VERIFIED | Medium operational | 9/10 | Provider authentication, model availability, billing, and live failure behavior were not tested. Request quotas do not cap provider spend. |
| F-06 | NOT VERIFIED | Low assurance | 9/10 | Android Keystore encryption, retention expiry, permission revocation, key-loss recovery, process death, and OEM behavior have not been tested on devices. |
| F-07 | OPEN QUALITY GAP | Medium confidence | 9/10 | Scam metrics use a 26-example synthetic fixture; they are not evidence of real-world precision, recall, F1, or false-positive rates. |
| F-08 | OPEN PRIVACY/RELIABILITY LIMITATION | Medium | 8/10 | `MessageNotificationListenerService.kt` has no per-app exclusion control, and `NotificationQueueStorage.kt` has no per-notification content-length bound. Consent is required and the queue is capped at 50 items, but capture breadth and oversized previews need explicit product/device validation. This is not a confirmed exploitable vulnerability. |
| F-09 | FIXED IN INTEGRATION; OPEN ON SECURITY REF | High | 10/10 | The security-branch MFA helper allows privileged users with no verified factor through at AAL1, and its scam-intelligence role predicates omit `super_admin`. The integration retains the stricter helper, trusted role, and regression tests; do not merge the security helper. |

F-09 is a confirmed authorization regression in the audited security-branch
snapshot; it is not present in the integration branch. Other open items above
are privacy, deployment, validation, and quality risks, not proven exploits.

## User-provided Docker scan evidence

A Docker Scout screenshot supplied after this review shows five Medium CVEs
in a truncated `public.ecr.aws/...` image view; four are marked fixable. The
image name/tag/digest and package versions are not visible, and the repo has no
Dockerfile or Compose file mapping that scan to a Cyvora artifact. The
screenshot's Alpine summary also appears to show a red severity count that
does not match the five Medium rows. This is unverified external evidence,
not a confirmed finding in a Cyvora image. See
[Docker image scan review](CYVORA_DOCKER_IMAGE_ANALYSIS.md) for the CVE list
and required follow-up.

## Authentication and authorization

- Flutter uses Supabase Auth and the publishable key; no service-role key is
  included in the client.
- Protected Edge Function paths validate the bearer token in source. The
  security-branch MFA helper does not require enrollment for a privileged
  user without a factor (F-09); the integration branch retains the stricter
  check. Deployed revisions and live authorization behavior were not checked.
- SQL migrations define RLS and restrict privileged RPC execution. The
  13-assertion security suite passed locally against disposable Supabase
  PostgreSQL. Separate local sessions confirmed per-user reservation-key
  isolation, no authenticated table SELECT/RPC execute privilege, and
  rejection of an authenticated direct RPC call. Hosted migration state and
  Edge Function authorization remain unverified.
- Family invitation creation/acceptance uses server-side RPCs, hashed tokens,
  expiration, and verified-email checks in source. Concurrent invitation
  behavior requires a PostgreSQL test.

## Database, Edge Functions, and AI

- Migrations `202611170001`–`202611170007` and the matching Edge Function
  calls are repository code. All 24 repository migrations were applied in
  order to a fresh disposable local database. No hosted migration ledger or
  deployed function revision was checked, and no deployment is claimed.
- Reapplying `202611170005`–`202611170007` to that migrated database passed.
  Catalog inspection found RLS enabled on all 31 public tables and fixed
  `search_path` settings on all public `SECURITY DEFINER` functions.
- The notification idempotency migrations use user/request keys,
  HMAC-based content fingerprints, a five-minute row-locked lease, a
  service-role-only reservation/record/release path, atomic scan persistence,
  deleted-history tombstones, and a 35-day cleanup job. The initial lease and
  replay behavior passed 14 pgTAP assertions and 7 separate-connection
  reservation checks locally. The migration fails if `pg_cron` is unavailable
  so retention cannot be silently assumed.
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
- No per-app exclusion setting or per-item title/text size cap was found.
  Their behavior on physical devices and the desired handling of oversized
  previews remain open product-validation items.
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

- Laravel is the official, separate Super Admin panel on the fix/integration
  branch. Its server-side Supabase integration does not require Flutter to
  call Laravel directly. This security-branch snapshot predates that panel;
  see the integration guide and current Super Admin test results.
- Release workflow source pins every action by full commit SHA, verifies
  stable-tag ancestry, uses separate `android-signing` and `android-publish`
  Environments, checks APK/AAB contents and the production certificate, and
  publishes drafts with write permission only in the publishing job. Fifteen
  release-policy/artifact tests passed locally. No release workflow run exists
  on this branch. The repository owner must configure required reviewers,
  environment deployment restrictions, protected `v*` tags, branch rules,
  and signing secrets; none of those GitHub settings were observable or
  changed. The expected application ID is `com.example.cyvora_mobile` and
  must be confirmed as the intended store identity.
- iOS/Xcode, physical Android devices, and OEM-specific behavior were not
  available in this Windows validation environment. Existing Android/iOS
  identifiers differ and were not changed.

## Final staging and release gate

The local release gate is **conditionally ready for isolated staging
validation, not ready for production**. No staging Supabase URL or credentials
or provider credentials were available. No physical Android device was
attached (`adb` was unavailable and the listed emulator was offline). The
Android release workflow has not run on this branch.

At the start of this validation, branch
`security/complete-production-hardening` and its upstream both pointed to
`392231280bbfaf1dc09096a77ebe4cbf0542e0bd`. The merge base with `origin/main`
was `83fba3ccc46563c9999069f732ab3fddaa462287`; the branch contained 36
changed files relative to `main` (+1,943/-172). Tracked files were clean at
audit start. One untracked `security-hardening-review.patch` (273,612 bytes)
was preserved. The local evaluation and documentation updates made during
this pass are uncommitted and must not be mistaken for remote branch state.

GitHub CI run [44074458843](https://github.com/XueShadow/Cyvora/actions/runs/44074458843)
passed both the Flutter and backend jobs for source commit `659b79d`; it is
not a run of current HEAD or the uncommitted evaluation change. Workflow source
review and local policy tests do not establish protected-environment
reviewers, deployment rules, secret presence/placement, branch protection, or
tag rulesets. These settings require manual repository-owner verification.

## Test results and limits

| Check | Result |
|---|---|
| Flutter analyze | PASS |
| Flutter tests | PASS — 66 |
| Supabase Node tests | PASS — 96; mocked/source-contract tests, not PostgreSQL |
| Android release validation unit tests | PASS — 15 tag-ref/artifact-validator tests; no release artifacts or workflow run verified |
| Android debug APK | PASS; no device install |
| PostgreSQL migration/RLS/idempotency pgTAP | PASS — 13 security-boundary and 14 idempotency assertions via direct psql on disposable Supabase PostgreSQL |
| Notification reservation separate-session checks | PASS — 7/7: contention, lease recovery, retry, completed replay, user isolation, RPC authorization, and transaction rollback |
| Latest migration reapplication and catalog checks | PASS — migrations 005–007 reapplied; no public tables without RLS and no public security-definer routines without fixed search paths |
| Scam evaluation fixture | PASS — 26 synthetic examples: 13 TP, 13 TN, 0 FP/FN; six paired categories; not a real-world estimate |
| GitHub CI | PASS — run 44074458843 for source commit 659b79d; not current HEAD |
| Deno, PHP/Composer, live providers, iOS/device tests | NOT RUN / UNAVAILABLE |
| Dependency advisory scans | NOT RUN by this validation; user-provided Docker Scout screenshot reviewed separately, but its image identity is unverified |

See [staging validation](CYVORA_STAGING_VALIDATION.md) for safe next steps,
[remediation report](CYVORA_REMEDIATION_REPORT.md) for changed behavior, and
[final checklist](CYVORA_FINAL_PRODUCTION_CHECKLIST.md) for release gates.
See the [device test plan](CYVORA_DEVICE_TEST_PLAN.md), [scam evaluation](CYVORA_SCAM_DETECTION_EVALUATION.md),
and [release security review](CYVORA_RELEASE_SECURITY.md) for remaining
manual validation.
