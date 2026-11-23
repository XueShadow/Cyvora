# Cyvora full code audit

**Audit date:** 2026-11-17
**Repository baseline:** `c8aab7970b30216a6477f6bd61486ce9d71c7a22` on `main`
**Mode:** Audit only. No application source, production database, credentials,
application identity, or signing configuration was changed.

## Executive summary

Cyvora is an existing Flutter + Supabase application with deterministic
server-side scam analysis, optional AI and URL intelligence, Family Protection,
and an intended Laravel Super Admin panel. The current architecture does not
require a rewrite. Local Flutter analysis/tests, backend tests, Android debug
build, and the latest GitHub CI run passed.

**Production readiness is not established.** The Supabase production migration
ledger showed `202611150005_mfa_enforcement` as its latest recorded migration.
The repository also contains `202611150006_scan_history_retention.sql` and
`202611170001`–`202611170004`, which were not present in that ledger. The
deployed Edge Function revisions are unknown. No PostgreSQL integration,
cross-user RLS test, live provider test, iOS build, or device notification test
was completed.

The specialist security review found no substantiated exploitable
vulnerabilities in the reviewed workspace. The detailed limits and privacy
gaps are in [the security audit](CYVORA_SECURITY_AUDIT.md).

## Architecture

See [the architecture map](CYVORA_ARCHITECTURE.md). In brief:

- Flutter provides authentication, MFA step-up, dashboard, scan, history,
  family, alert, and settings UI.
- `DashboardRepository` separates much of the UI from Supabase queries and
  Edge Function calls.
- `scam-intelligence` coordinates deterministic modules, optional AI and URL
  reputation, persistence, assistant chat, and trusted-intelligence
  operations.
- `family-invitations` manages invite lifecycle using server-side privileged
  database operations.
- PostgreSQL migrations define data structures, RLS, RPCs, quotas, and
  retention behavior.
- Android notification capture is a native listener plus an in-app manual
  review flow; it does not replace the default SMS app.
- Laravel is the intended Super Admin component, but currently serves only a
  default welcome page; no admin auth/RBAC or Cyvora API boundary was found.
- CI covers Flutter dependency validation, analysis, widget tests, Android
  debug build, and Supabase Node tests. The release workflow is separate.

## Prioritized audit findings

| Priority | Severity | Finding and root cause | Impact | Recommendation |
|---|---|---|---|---|
| 1 | HIGH | **Production schema is behind repository migrations.** `supabase/migrations/202611150006_scan_history_retention.sql`, `supabase/migrations/202611170001_atomic_family_invite_limit.sql`, and `supabase/migrations/202611170002_ai_provider_guardrails.sql` through `202611170004_ai_request_dedup_quota_reservation.sql` are absent from the observed ledger. `supabase/functions/scam-intelligence/index.ts` calls versioned AI RPCs; `supabase/functions/family-invitations/index.ts` calls the invite RPC. | If newer Edge Functions are deployed against the older schema, family invite creation and optional AI reservations may fail because their RPCs are missing. Scan-history retention may also differ from repository expectations. | Apply pending migrations in timestamp order in isolated staging, run database/RLS/concurrency tests, verify function revisions, then use an approved production deployment plan. No SQL was executed in this audit. |
| 2 | HIGH | **Mobile identifiers do not agree.** `flutter/android/app/build.gradle.kts` sets Android namespace/application ID to `com.example.cyvora_mobile`; `flutter/ios/Runner.xcodeproj/project.pbxproj` sets iOS bundle ID to `com.example.cyvoraMobile`. Both are example identifiers, and the production App Store identity is not confirmed. | Android and iOS may be treated as distinct apps, and changing an already released identity can break updates, signing, or callbacks. | Have the owner confirm the canonical identities and release history. Do not change IDs or signing material without explicit approval. |
| 3 | MEDIUM | **Notification monitoring is review-driven, not automatic.** `flutter/android/app/src/main/kotlin/com/example/cyvora_mobile/MessageNotificationListenerService.kt:onNotificationPosted` queues previews; `flutter/lib/dashboard/dashboard_screen.dart:_showPermissionCenter` and `_reviewPendingMessageNotifications` expose manual review and scan only an item the user selects. No background queue worker was identified. | The stated automatic-analysis requirement is not met; queued notifications can remain unexamined. | Define consent and foreground/background behavior, then implement a tested queue processor with revocation and failure handling. |
| 4 | MEDIUM | **A queued preview can be lost when scanning fails.** `flutter/lib/dashboard/dashboard_screen.dart:_reviewPendingMessageNotifications` removes the selected item before calling `_analyze`. | A transient network/service error prevents retry from the pending queue. | Remove only after successful processing or explicit user discard; test failure and retry paths. |
| 5 | MEDIUM | **Notification preview retention is bounded by count, not time.** `flutter/android/app/src/main/kotlin/com/example/cyvora_mobile/MessageNotificationListenerService.kt` stores title/text/package metadata in app-private preferences and caps the queue at 50; no time-based expiry or application-layer encryption was identified. | Sensitive previews may remain on-device until scanned or displaced. App-private storage is not equivalent to application-layer encryption. | Define a short TTL, explicit clear control, minimize stored fields, and evaluate Keystore-backed encryption against the threat model. |
| 6 | MEDIUM | **Detection metrics are not production-quality evidence.** `supabase/tests/scam-evaluation.test.mjs` contains 14 synthetic cases and reports perfect fixture scores. | It cannot establish real-world precision, recall, F1, or false-positive rates across scam categories or language variants. | Build a moderator-reviewed, representative Filipino/Taglish and English dataset with a held-out split and release gates. |
| 7 | HIGH | **The intended Laravel Super Admin panel is not implemented.** The product owner confirms its role; `laravel/routes/web.php` exposes only the default welcome route, with no admin login, RBAC, management dashboard, or Supabase integration. | The requested privileged administration workflows and their access controls cannot be used or tested. This is a major incomplete feature, not evidence that Laravel is unnecessary or an exploitable vulnerability. | Define the admin identity, roles, data access, and audit-log contract; then implement deny-by-default routes and role-separated tests before connecting sensitive data. |
| 8 | MEDIUM | **Integration test coverage is missing for production-critical controls.** `supabase/tests/*.test.mjs` uses mocks/static SQL checks; no PostgreSQL, separate-account RLS, family isolation, or live provider test ran. | Race conditions, schema drift, and deployment errors can pass local CI. | Add isolated PostgreSQL/Supabase integration tests and a staging deployment gate. |
| 9 | LOW | **Large feature files concentrate unrelated UI and data access.** `flutter/lib/dashboard/dashboard_screen.dart` contains multiple screens and flows; `flutter/lib/dashboard/dashboard_repository.dart` covers many feature domains. | Changes are harder to isolate and review as the app grows. | Extract feature-level widgets/repositories incrementally after release blockers are addressed; no rewrite is recommended. |

## Baseline verification

See [baseline test results](CYVORA_TEST_RESULTS.md):

- Flutter analysis: PASS.
- Flutter widget tests: 59 PASS.
- Supabase backend Node tests: 89 PASS.
- Android debug APK: PASS, with toolchain warnings.
- GitHub Actions run [44035823882](https://github.com/XueShadow/Cyvora/actions/runs/44035823882): PASS for `c8aab797`.
- Laravel tests: BLOCKED because PHP is unavailable.
- PostgreSQL/Deno/iOS/device/live-provider validation: NOT TESTED or BLOCKED.

## Audit-only changes

This audit adds or updates documentation only. No source fixes, migrations,
function deployments, secret changes, package-ID changes, or signing changes
were made. Implementation work should begin only after the owner approves the
priority and scope.

## Follow-up verification — 2026-11-23

**Current HEAD:** `3d8ed60c450db25e02f754f408e41f25dc1282db` on
`fix/mlkit-release-crash`. The worktree already contained user changes when
this follow-up began. No application source, signing material, production
database, or deployment configuration was changed by this follow-up.

### New release blocker

| Priority | Finding | Evidence and impact | Required action |
|---|---|---|---|
| HIGH | **The locally built Android release artifacts do not satisfy the configured production signer check.** `flutter/android/app/build.gradle.kts` uses the local release signing configuration; `flutter/scripts/validate_android_release.py` checks the APK and AAB in `verify_apk_signature()`, `verify_aab_signature()`, and `validate()`, and `.github/workflows/android-release.yml` runs that validator before staging. | The APK and AAB signatures both verify cryptographically and use the same signer, but neither signer matches the validator's configured identity. The artifact validator failed on the APK; an independent AAB check confirmed the same mismatch. These local artifacts cannot pass the repository's release gate. The protected CI signing secret was not accessed, so the CI release identity and workflow outcome remain unverified. This is not evidence that a signing key is compromised. | Have the owner confirm the authorized release identity and verify that both local and protected CI signing configurations use it. Rebuild and rerun the artifact validator. Do not change the expected fingerprint or signing identity to make the check pass without owner approval. |

### Scan-history retention change in the current worktree

The current worktree removes the 120-day cleanup-on-history-read from
`SupabaseDashboardRepository.loadScanHistory()` in
`flutter/lib/dashboard/dashboard_repository.dart`. Its accompanying
`supabase/migrations/202611230001_preserve_scan_history.sql` unschedules the
`delete-expired-scan-history` job when present and drops its cleanup function.
The current privacy text in `flutter/lib/auth_screen.dart` says scan history
is retained until the user deletes it or requests account deletion. These
changes are consistent with one another, but the migration and deletion
lifecycle were not tested against PostgreSQL or the deployed project. The
last observed production migration ledger is from 2026-11-17 and is not a
current deployment check.

### Follow-up checks

- Flutter analysis: PASS.
- Flutter tests: PASS — 64.
- Supabase Node tests: PASS — 90 (unit/mocked and static checks).
- Android release workflow/ref/artifact policy tests: PASS — 15.
- Laravel tests: PASS — 2; Composer manifest/lock validation: PASS.
- Android debug APK, release APK, and release AAB builds: PASS.
- APK and AAB cryptographic signature checks: PASS; configured production
  identity check: FAIL for both artifacts.
- Production PostgreSQL/RLS, deployed Edge Functions, live providers, iOS,
  and physical-device notification behavior: NOT TESTED. Supabase CLI, Deno,
  PostgreSQL client, and a running Docker engine were unavailable; no Android
  device was connected.

See [current test results](CYVORA_TEST_RESULTS.md),
[production readiness](CYVORA_PRODUCTION_READINESS.md),
[security audit](CYVORA_SECURITY_AUDIT.md), and the
[remediation log](CYVORA_REMEDIATION_LOG.md) for details. The production
readiness verdict remains **NOT PRODUCTION READY**.

### Laravel Super Admin follow-up — 2026-11-23

The product owner confirms Laravel is the intended Super Admin panel. The
route inventory (`php artisan route:list --json`) contains five routes, with
no admin, login, or logout routes. The application exposes the framework
welcome page and a development-only Boost browser-log route; no Laravel
Supabase client or privileged data path was found. Laravel is therefore
important but not implemented yet.

The two passing Laravel tests exercise only scaffold behavior; they do not
cover authentication, role separation, authorization, administrative data
access, CSRF, audit logging, or Supabase integration. No role-separated test
can establish access control until those features exist. The unauthenticated
Boost route is conditional on development dependencies being present in a
deployment; the production Composer install mode was not inspected.

As a narrow defense-in-depth change, `laravel/config/session.php` now
defaults the session cookie's `Secure` attribute on for `APP_ENV=production`
while preserving the local default and explicit environment override. Artisan
configuration checks passed for all three cases. This does not substitute for
Super Admin authentication or authorization.
