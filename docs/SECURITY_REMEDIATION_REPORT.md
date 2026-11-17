# Cyvora Security Remediation Report

**Status date:** 2026-11-17

**Scope:** Repository source and local checks only. No production credentials,
database, GitHub settings, or provider accounts were accessed.

## Executive summary

The local changes address the Android release-ref trust boundary and Android
notification reliability/privacy findings without changing the Flutter +
Supabase + Laravel architecture. Release policy, Flutter, Node, and Android
debug-build checks pass. PostgreSQL execution, GitHub owner configuration,
live providers, device behavior, and dependency advisories remain unverified.

## Findings and remediation

| ID | Severity / status | Affected files | Root cause | Implemented change and evidence |
|---|---|---|---|---|
| F-01 | HIGH / FIXED IN SOURCE; OWNER CONFIG REQUIRED | `.github/workflows/android-release.yml`, `flutter/scripts/validate_android_release_ref.py`, `flutter/scripts/validate_android_release.py` | A release tag could previously select an arbitrary commit, while signing and publish permissions were not isolated by job. | Stable tags are validated against the default branch; the validated SHA is built; artifact tag/version and signing identity are checked; build/sign and publish use separate least-privilege jobs and protected Environments; release publication is a draft. Fifteen release-ref/artifact/workflow policy tests pass. Actual GitHub rules and approvals are not verified. |
| N-01 | MEDIUM reliability / FIXED IN SOURCE | `flutter/lib/core/permissions/message_notification_service.dart`, `flutter/lib/dashboard/dashboard_screen.dart`, `flutter/android/app/src/main/kotlin/com/example/cyvora_mobile/NotificationQueueStorage.kt` | Queue entries were removed before analysis success, and failed requests did not have a retry path. | The item stays queued until analysis succeeds. Successful results are durably marked in the encrypted queue before cleanup; retry cleanup does not re-run analysis. Failed scans remain retryable. Flutter queue tests pass. Exact crash windows and Android process-death behavior remain device-unverified. |
| N-02 | MEDIUM privacy / FIXED IN SOURCE; DEVICE TESTING REQUIRED | `flutter/android/app/src/main/kotlin/com/example/cyvora_mobile/NotificationQueueStorage.kt`, `MessageNotificationListenerService.kt`, `NotificationQueueExpiryReceiver.kt`, `MainActivity.kt`, `flutter/lib/dashboard/dashboard_screen.dart`, `AndroidManifest.xml` | Notification previews were plaintext and had no time-based retention or explicit Cyvora consent. | AES/GCM uses an Android Keystore key; legacy plaintext entries are migrated durably; retention is selectable as 1/7/30 days (default 7); expiry is scheduled; backups are disabled; previews can be deleted. Consent defaults off; revocation requires confirmation and clears the queue. An unreadable encrypted queue can be explicitly deleted. Android debug build passes; device/key-loss tests were not run. |
| DB-01 | MEDIUM assurance / LOCAL DATABASE TESTS PASS; STAGING/PRODUCTION UNVERIFIED | `supabase/tests/security_boundaries.test.sql`, `supabase/tests/family-invitation-quota.test.mjs` | Source and mocked tests alone cannot establish actual RLS/RPC behavior or database concurrency. | The 13-assertion pgTAP suite passed against a disposable Supabase PostgreSQL container. Static Node tests check atomic invitation locking and invitation consumption. True multi-connection races and deployed policies remain unverified. |
| AI-01 | MEDIUM cost-control limitation / NOT FIXED | `supabase/functions/_shared/ai-provider-analysis.ts`, `supabase/functions/scam-intelligence/index.ts`, `supabase/migrations/202611170002_ai_provider_guardrails.sql`–`202611170004_ai_request_dedup_quota_reservation.sql` | Request quotas and concurrency limits do not provide a monetary ceiling; provider prices vary by model and account. | Existing fail-closed request budgets, cooldowns, deduplication, concurrency leases, timeouts, response validation, and circuit-breaker behavior have mocked coverage in the Node suite. No prices or token costs were guessed. Configure spending caps with each provider. Failed attempts release concurrency leases but remain counted as attempted requests. |

## Validation results

- Flutter analyze: **PASS**, no issues.
- Flutter tests: **PASS, 66 tests**.
- Supabase Node tests: **PASS, 96 tests**.
- Android release/ref/artifact/workflow policy tests: **PASS, 15 tests**.
- Android debug APK build: **PASS**.
- pgTAP security-boundary suite: **PASS — 13 assertions** via direct `psql`
  against disposable Supabase PostgreSQL. This was not a hosted staging run.
- Notification idempotency pgTAP suite: **PASS — 14 assertions** against the
  same disposable database; true multi-session concurrency remains untested.
- Dependency advisory scans: **NOT RUN**; available environment did not
  include `dart pub audit`, PHP/Composer, a Laravel npm lockfile, or a scanner.
- Live providers, production migration ledger, and Android physical/OEM
  behavior: **NOT TESTED**.

See [Testing and Validation](./TESTING_AND_VALIDATION.md) for commands and
limitations.

## Remaining risks and required manual actions

1. Configure protected default-branch and `v*` tag rulesets. Add required
   reviewers to `android-signing` and `android-publish`; move signing secrets
   exclusively into `android-signing`; remove repository-level copies.
2. Run the pgTAP suite and separate multi-connection invitation/quota tests
   against a disposable local Supabase database or isolated staging project.
   Never run fixture cleanup or migrations against production.
3. Test notification expiry, revocation, key loss, migration, process death,
   and backup behavior on supported Android devices/OEMs.
4. Do not send passwords, verification codes, or other secrets for analysis.
   The UI warns users, but scan text is not currently locally redacted before
   an optional AI provider request.
5. Configure provider-side spending limits and review provider retention and
   billing terms. No provider pricing was assumed.
6. Confirm the deployed migration ledger and Edge Function revisions in
   staging before planning a production deployment. Nothing was deployed.

The pasted specification snapshot ended partway through its requested status
definitions; this report uses explicit `FIXED`, `PREPARED, NOT RUN`,
`NOT TESTED`, and `OWNER CONFIG REQUIRED` labels to preserve the evidence
boundary.
