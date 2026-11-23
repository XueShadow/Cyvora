# Cyvora Production Readiness Report

**Status date:** 2026-11-17

**Production release approval:** **NOT READY / NOT VERIFIED**

> **Integration status (2026-11-23):** This dated report records an earlier
> readiness snapshot. The current integration branch includes the official
> Laravel Super Admin panel and keeps its privileged MFA/authz controls.
> Current local results are 102 Supabase Node tests, 70 Flutter tests,
> Flutter analysis, 15 Android release-policy tests, and an Android debug
> build. PostgreSQL/pgTAP and hosted deployment checks remain unverified.
> See [current readiness](CYVORA_PRODUCTION_READINESS.md),
> [test results](CYVORA_TEST_RESULTS.md), and
> [the Super Admin guide](CYVORA_SUPER_ADMIN_GUIDE.md).

## Architecture and operational boundary

Cyvora remains a Flutter/Dart client, Supabase Auth/PostgreSQL/Edge Functions
backend, Android Kotlin notification-listener integration, and an intended
Laravel Super Admin panel. Laravel is implemented as the official, separate
server-rendered admin application, with server-side Supabase integration; it
does not require direct Flutter-to-Laravel API calls. The old scaffold-only
assessment below was true only of the historical audit baseline.

No production migration, Edge Function, signed release, provider request, or
GitHub repository setting was changed. The previous observed production
migration ledger is historical evidence only; current deployed schema and
function revisions were not checked.

## Readiness matrix

| Area | Status | Evidence / remaining work |
|---|---|---|
| Android release ref and artifact validation | FIXED IN SOURCE | Stable version tags must resolve to the default branch; build uses the validated commit SHA; tag/version, APK/AAB signatures, package identity, and previous-version rules are validated. Fifteen policy tests pass. No signed release was built. |
| GitHub protected rules and release environments | REQUIRES MANUAL CONFIGURATION | Configure default-branch and `v*` tag rulesets, required reviewers for `android-signing` and `android-publish`, and signing secrets only in `android-signing`. Repository settings were not inspected or changed. Releases are created as drafts. |
| Notification consent and local storage | IMPLEMENTED IN SOURCE; DEVICE TESTING REQUIRED | Consent defaults off; revocation confirms and clears queued previews. Previews use AES/GCM and Android Keystore; retention options are 1/7/30 days; expiry is scheduled; backups are disabled; encrypted completion markers prevent cleanup retries from re-analyzing. Key-loss and OEM lifecycle tests are not available here. |
| Notification queue processing | VERIFIED IN FLUTTER TESTS | Failed analysis keeps the item; retry works; concurrent duplicates are suppressed; successful completion is persisted before queue cleanup. Five focused queue/platform-channel tests are included in the 64-test suite. Process-restart and native storage cases remain untested on-device. |
| Supabase RLS, RPCs, migrations | LOCAL pgTAP PASS; STAGING/PRODUCTION UNVERIFIED | The 13-assertion security suite and 14-assertion notification idempotency suite passed against a disposable Supabase PostgreSQL container after applying repository migrations. This used direct `psql`, not full CLI orchestration or hosted staging; true multi-session race tests remain required. |
| Edge Function and provider behavior | MOCKED TESTS PASS; LIVE NOT TESTED | Existing tests cover authentication/error handling, bounds, timeouts, response validation, fallback controls, cooldowns, quota/circuit behavior. No provider credentials or live endpoints were used. |
| AI spending | REQUIRES PROVIDER-SIDE LIMITS | Request-count quotas do not cap dollars. Prices vary by configured provider/model; no token costs or financial budget are fabricated. |
| Scam detection | SYNTHETIC FIXTURE ONLY | Node tests report 7 TP, 0 FP, 7 TN, 0 FN on a 14-example fixture. This is not a real-world accuracy estimate. A reviewed and held-out multilingual/Filipino dataset is still required. |
| Android platform | DEBUG BUILD VERIFIED; DEVICE NOT TESTED | Debug APK build passes. No physical device, OEM-specific background/permission behavior, or release signing was tested. |
| Laravel Super Admin | IMPLEMENTED IN FIX/INTEGRATION; DEPLOYMENT NOT VERIFIED | The current branch contains the intended separate panel and focused tests. Hosted authentication/configuration and production route inventory were not tested. |
| Dependencies | NOT VERIFIED | `dart pub audit` is not present in the installed SDK; PHP/Composer and advisory scanners were unavailable; Laravel has no npm lockfile. |
| iOS | NOT TESTED | Xcode/signing/device validation is unavailable on this Windows environment. |

## Validation summary

- Flutter analyze: PASS.
- Flutter tests: PASS, 66.
- Supabase Node tests: PASS, 96.
- Android release/ref/artifact/workflow policy tests: PASS, 15.
- Android debug build: PASS.
- PostgreSQL/pgTAP tests: 27 assertions passed locally; hosted staging and
  true multi-session concurrency are not verified.
- Live provider, Laravel, dependency advisory, Android device/OEM, and iOS
  checks: not run.

See [Testing and Validation](./TESTING_AND_VALIDATION.md) and
[Security Remediation](./SECURITY_REMEDIATION_REPORT.md).

## Release gates

1. Owner configures and verifies protected branch/tag rules and GitHub
   Environment approvals/secrets.
2. Isolated local/staging database applies and tests migrations and RLS.
   Verify deployed Edge Function revisions match the tested schema.
3. Configure provider-side spend limits and verify plans, pricing, and data
   retention in staging.
4. Validate notification encryption, expiry, consent revocation, key-loss
   handling, and process-death behavior on supported devices.
5. Continue verifying Laravel Super Admin authentication, authorization,
   Supabase access boundaries, audit logging, and deployment configuration;
   complete dependency advisory scans and iOS platform validation where
   toolchains exist.
6. Review detection metrics on a sufficiently representative held-out dataset.
7. An owner reviews the signed artifacts and publishes the GitHub draft
   release manually.

No production changes were made. Passing local checks do not constitute
production certification.

## Laravel Super Admin follow-up — 2026-11-23

The five-route inventory and two-test scaffold result below were captured
against a historical branch snapshot that lacked the Laravel implementation
on `fix/mlkit-release-crash`; they do not describe the current integration
branch. The integrated panel has protected routes, role/permission checks,
server-side Supabase access, and focused tests. Production Composer mode,
hosted configuration, and deployed route inventory remain unverified. The
session cookie's `Secure` default under `APP_ENV=production` remains defense
in depth; confirm development-only routes are absent from production.
