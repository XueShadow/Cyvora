# Cyvora full code audit

> **Current status update:** This report is the pre-remediation audit snapshot.
> Release workflow hardening, encrypted/retained notification storage, queue
> retry, and notification scan idempotency source changes have since been
> added on `security/complete-production-hardening`. Repository migrations
> through `202611170007` and both pgTAP suites have since passed locally on a
> disposable Supabase PostgreSQL container; hosted staging and production
> were not tested. The latest synthetic evaluation contains 26 cases across
> six paired categories (13 TP, 13 TN, 0 FP/FN); it is still not a real-world
> estimate. Seven independent-session notification reservation checks also
> passed locally. Existing findings and counts below describe their original
> baseline. See the
> [current complete security audit](CYVORA_COMPLETE_SECURITY_AUDIT.md),
> [remediation report](CYVORA_REMEDIATION_REPORT.md), and
> [final checklist](CYVORA_FINAL_PRODUCTION_CHECKLIST.md).

**Audit date:** 2026-11-17
**Repository baseline:** `c8aab7970b30216a6477f6bd61486ce9d71c7a22` on `main`
**Mode:** Audit only. No application source, production database, credentials,
application identity, or signing configuration was changed.

## Executive summary

Cyvora is an existing Flutter + Supabase application with deterministic
server-side scam analysis, optional AI and URL intelligence, Family Protection,
and a standalone Laravel scaffold. The current architecture does not require a
rewrite. Local Flutter analysis/tests, backend tests, Android debug build, and
the latest GitHub CI run passed.

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
- Laravel currently serves a default welcome page; no Cyvora API boundary was
  identified.
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
| 7 | MEDIUM | **Laravel has no defined Cyvora role.** `laravel/routes/web.php` exposes the default welcome route and `laravel/tests/Feature/ExampleTest.php` is a scaffold test; no client/API integration was identified. | Responsibility, auth boundaries, and deployment ownership are unclear. | Confirm whether Laravel is required and document its contract before implementing or removing anything. |
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
