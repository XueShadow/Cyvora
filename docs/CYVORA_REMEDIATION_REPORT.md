# Cyvora Remediation Report

## Scope and safety

Remediation was performed on the separate branch
`security/complete-production-hardening`, starting from `83fba3c`. Existing
Flutter, Supabase, PostgreSQL, Android, and Laravel architecture was retained.
No production database, provider, GitHub repository setting, release secret,
or deployment was accessed or changed.

## Changes by phase

### 1. Android release security

- Kept release ref validation against the default branch and stable tag policy.
- Kept signing and publishing behind separate `android-signing` and
  `android-publish` GitHub Environments, with least-privilege job permissions
  and draft release publishing.
- Expanded the workflow's local release-policy test step to run all three
  Python test modules (15 tests), not only the tag-ref test.
- Updated root and Flutter release guidance with manual owner configuration.

**Manual:** Configure Environment required reviewers/restrictions, protected
default-branch and `v*` tag rulesets, and place signing secrets only in the
signing Environment. Source configuration does not create GitHub settings.

### 2. Notification reliability and duplicate prevention

- Queue items remain available when analysis fails; success is marked durably
  before local removal and a retry is available.
- Stable notification revision IDs are carried from the Android listener
  through Flutter to `scam-intelligence`. Notification content is not included
  in request IDs.
- Added `202611170005_notification_scan_idempotency.sql` with user-scoped
  reservation keys, HMAC fingerprints, row-locked leases, atomic result
  persistence/replay, and deletion tombstones.
- Corrected the initial reservation path so a new key returns its lease as
  `reserved` instead of being mistaken for an in-progress duplicate; added
  forward migration `202611170007_notification_scan_reservation_initial_lease.sql`.
- Added forward migration `202611170006_family_invite_auth_compat.sql` so
  verified invitation acceptance supports both `confirmed_at` and legacy
  `email_confirmed_at` Supabase Auth schemas.
- Requests in progress return a retryable conflict; changed content cannot
  reuse the same request key; completed responses are replayed without a
  second scan record.
- Automated database cleanup retains idempotency records for up to 35 days.
  The migration fails if `pg_cron` is unavailable rather than silently
  omitting the schedule.
- Added focused Node source-contract tests and a 14-assertion pgTAP suite.

Separate-connection tests passed 7/7 for reservation contention, lease
recovery, retry after failure, completed replay without duplicate rows,
per-user key isolation, RPC permissions, and rollback after transaction
failure. If a provider call succeeds and the process fails before the
transaction commits, retry after lease expiry can call the provider again.

### 3. Notification privacy

- Existing encrypted Android queue, explicit consent, configurable 1/7/30-day
  retention, expiry, user deletion, and no-content logging behavior were
  preserved.
- Consent-revocation UI explains that an already submitted scan cannot be
  recalled.
- Optional AI provider content is minimized server-side before external
  provider requests. The minimizer is heuristic; it is not on-device and
  cannot guarantee redaction of every identifier or secret.
- Added idempotency response retention and cleanup. No plaintext notification
  is placed in the idempotency key.
- No per-app exclusion control or per-notification payload-size cap was found.
  These remain product/privacy and reliability decisions for device testing;
  this pass did not silently truncate or discard user notification content.

### 4. Supabase staging verification preparation

- Retained the prepared `security_boundaries.test.sql` suite (13 assertions)
  for RLS, family access, RPC permissions, invitation lifecycle, and quotas.
- Added `notification_scan_idempotency.test.sql` (14 assertions) for duplicate
  reservation, fingerprint mismatch, release/retry, atomic completion/replay,
  deleted-history behavior, RPC access, and cleanup scheduling.
- Updated Supabase setup/provider documentation with local-vs-staging limits.
- Applied repository migrations through `202611170007` to a disposable
  Supabase PostgreSQL 17.11.0.018 container. Both SQL suites passed via direct
  `psql`: 13 security-boundary and 14 idempotency assertions. The bare image
  required test-only Auth and Storage schema helpers; this was not a full
  Supabase CLI stack or hosted staging run.
- Reapplied migrations `202611170005`–`202611170007` after the fresh migration
  run. Catalog checks found no public tables without RLS and no public
  `SECURITY DEFINER` functions without a fixed `search_path`.
- Previously completed separate-connection reservation checks were not
  repeated.

### 5. AI provider validation

- Confirmed source-level request validation, bounded timeouts, response
  parsing, optional fallback behavior, and request quotas through existing
  Node tests.
- No live provider authentication, model catalog, billing, response, or quota
  was tested. Provider secrets were not read or changed.
- Provider request limits are not dollar-spend caps; owners must set provider
  billing limits.

### 6. Dependency and platform verification

- Flutter analysis, Flutter tests, Supabase Node tests, release policy tests,
  and Android debug build were run successfully.
- Advisory scanners, PHP/Composer, Deno, PostgreSQL/Supabase CLI, iOS/Xcode,
  and physical Android/OEM verification were unavailable or not run. No
  dependency-security result is claimed.
- A user-provided Docker Scout screenshot was reviewed, but its truncated
  image reference prevents attribution to a Cyvora artifact. No image scan or
  remediation was performed; see the Docker image analysis.
- The focused synthetic scam evaluation was expanded from 14 to 26 examples
  and passed: 13 TP, 13 TN, 0 FP, 0 FN. It remains a small regression fixture,
  not real-world accuracy evidence.

### 7. Documentation

Added:

- [Complete security audit](CYVORA_COMPLETE_SECURITY_AUDIT.md)
- [Staging validation plan](CYVORA_STAGING_VALIDATION.md)
- [Final production checklist](CYVORA_FINAL_PRODUCTION_CHECKLIST.md)
- [Physical-device test plan](CYVORA_DEVICE_TEST_PLAN.md)
- [Synthetic scam-detection evaluation](CYVORA_SCAM_DETECTION_EVALUATION.md)
- [Release security review](CYVORA_RELEASE_SECURITY.md)
- [Docker image scan review](CYVORA_DOCKER_IMAGE_ANALYSIS.md)

Updated:

- [Independent code audit](CYVORA_INDEPENDENT_CODE_AUDIT.md)
- [Production readiness](CYVORA_PRODUCTION_READINESS.md)
- [Security notes](SECURITY.md)
- [Test results](CYVORA_TEST_RESULTS.md)
- Supabase provider/backend guidance and repository release guidance

## Validation summary

| Validation | Result |
|---|---|
| `flutter analyze --fatal-infos` | PASS |
| `flutter test --no-pub` | PASS — 66 tests |
| Node test suite | PASS — 96 tests |
| Android release policy tests | PASS — 15 tests |
| `flutter build apk --debug --no-pub` | PASS |
| SQL migration/pgTAP execution | PASS — 27 assertions on disposable local PostgreSQL; 005–007 reapplied successfully |
| Scam evaluation | PASS — 26 synthetic examples; 13 TP, 13 TN, 0 FP/FN; not a real-world estimate |
| Live providers, production deployment, device/iOS tests | NOT RUN |

See [test results](CYVORA_TEST_RESULTS.md) for detailed limitations. The work
is ready for isolated staging validation only; production readiness has not
been established.
