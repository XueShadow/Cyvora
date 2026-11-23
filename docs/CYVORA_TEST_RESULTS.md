# Cyvora test results

**Verification date:** 2026-11-23
**Integration branch:** `integration/production-hardening`
**Scope:** Focused validation of the MFA and notification-reservation fixes. Earlier test counts below are from the fix-branch baseline, before this integration.

## Pre-integration baseline verification

| Check | Result | Notes |
|---|---|---|
| `flutter analyze --fatal-infos` | **PASS** | No issues found. |
| `flutter test --no-pub` | **PASS — 67 tests** | Includes TOTP challenge UI, notification queue retries/idempotency behavior, Auth/MFA, dashboard, family, scan, and privacy flows. |
| `node --test supabase/tests/*.test.mjs` | **PASS — 98 tests** | Includes privileged MFA and notification-idempotency regressions; provider flows are mocked and SQL assertions are static. |
| `php artisan test` | **PASS — 28 tests, 125 assertions** | Covers Laravel authentication, mandatory factor enrollment, AAL2, roles, route authorization, reauthentication, and Supabase client integration using HTTP fakes. |
| `vendor/bin/pint --test` | **PASS** | Run after the final Laravel edits. |
| Android debug build | **PASS** | `flutter build apk --debug` built the debug APK. Gradle emitted a Java native-access warning. |
| `supabase/tests/security_boundaries.test.sql` | **PREPARED — 17 assertions; NOT RUN** | Includes RLS, family access, privileged MFA, unauthorized RPC, invite lifecycle, cascade, audit immutability, and AI quota checks. |
| `supabase/tests/notification_scan_idempotency.test.sql` | **PREPARED — 14 assertions; NOT RUN** | Covers reservation leases, retries, atomic scan persistence, replay, and deletion tombstones. |

## Not run / blocked

| Check | Result | Reason |
|---|---|---|
| PostgreSQL migration and pgTAP execution | **NOT TESTED** | Supabase CLI and PostgreSQL runtime are unavailable. The migration and SQL test files have not been applied to any database. The notification-idempotency migration requires `pg_cron` for retention cleanup. |
| Deno Edge Function runtime/type checks | **NOT TESTED** | Deno is not installed. |
| Supabase hosted Auth, RLS, and Edge Function checks | **NOT TESTED** | No staging/production project was accessed; source presence does not prove deployment. |
| Live AI/reputation provider connectivity, billing, and retention | **NOT TESTED** | No provider credentials or live requests were used. |
| Android physical-device/OEM tests | **NOT TESTED** | No device validation was performed in this run. |
| iOS build/signing/device test | **BLOCKED** | Xcode/macOS is unavailable on this Windows host. |
| Android release artifact identity | **BLOCKED** | A prior local APK/AAB check found the signer did not match the release validator's expected identity. Owner confirmation and matching protected signing configuration are required. |

## Integration branch validation

| Check | Result |
|---|---|
| `flutter analyze --fatal-infos` | **PASS** |
| `flutter test --no-pub` | **PASS — 70 tests** |
| `node --test supabase/tests/*.test.mjs` | **PASS — 102 tests** |
| `python -m unittest discover -s flutter/scripts -p "test_*.py"` | **PASS — 15 tests** |
| `flutter build apk --debug --no-pub` | **PASS** — Gradle emitted a Java native-access warning. |
| PostgreSQL migration and pgTAP suites | **NOT RUN** — Docker daemon unavailable; forward migration remains unapplied. |
| Laravel tests and Pint | **NOT RERUN** — no Laravel application code changed in the integration merge. |

The current fix branch already enforced privileged MFA enrollment and AAL2.
The integration retains that implementation and adds regression tests. The
notification reservation correction is a forward migration; no database
application is claimed. The incoming security branch's historical test
reports for PostgreSQL, separate-session concurrency, and catalog checks were
not reproduced in this pass.

## Interpretation

Passing local tests demonstrate source-level behavior under local test doubles.
They do not verify deployed Supabase migrations, RLS grants, current Auth
configuration, deployed Edge Function revisions, live provider behavior,
production signing, or physical-device behavior. **Production readiness is
not established.**

See the [full security audit](CYVORA_FULL_SECURITY_AUDIT.md),
[production-readiness assessment](CYVORA_PRODUCTION_READINESS.md), and
[deployment guide](CYVORA_SUPER_ADMIN_DEPLOYMENT.md).
