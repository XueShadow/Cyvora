# Cyvora production readiness

> **Current branch update:** This report's original migration-ledger and test
> snapshots below are historical and were not rechecked against production.
> Current local results on `security/complete-production-hardening` are
> Flutter analyze PASS, Flutter tests PASS (66), Supabase Node tests PASS
> (96), Android release policy tests PASS (15), and Android debug APK PASS.
> Local pgTAP suites PASS (13 security-boundary and 14 idempotency assertions)
> against a disposable Supabase PostgreSQL container. No production changes
> were made.
> The current verdict is **CONDITIONALLY READY FOR ISOLATED STAGING
> VALIDATION; NOT READY FOR PRODUCTION**. See the
> [current complete security audit](CYVORA_COMPLETE_SECURITY_AUDIT.md),
> [remediation report](CYVORA_REMEDIATION_REPORT.md), and
> [final checklist](CYVORA_FINAL_PRODUCTION_CHECKLIST.md).

**Assessment date:** 2026-11-17
**Repository:** `XueShadow/Cyvora`
**Inspected commit:** `c8aab7970b30216a6477f6bd61486ce9d71c7a22`
**Production changes during this audit:** None

## Status definitions

- **IMPLEMENTED** — source or configuration is present.
- **VERIFIED** — the stated check was actually run and passed.
- **PARTIALLY IMPLEMENTED** — some support exists, but key behavior or
  verification is incomplete.
- **NOT TESTED** — no relevant runtime/integration test was performed.
- **BLOCKED** — required tooling, hardware, approval, or external access was
  unavailable.
- **REQUIRES MANUAL ACTION** — an owner must configure, approve, or verify an
  item outside source code.

## Executive summary

The existing Flutter + Supabase architecture is intact. Local Flutter
analysis, widget tests, Supabase backend tests, and an Android debug build
passed. GitHub Actions run [44035823882](https://github.com/XueShadow/Cyvora/actions/runs/44035823882)
passed for commit `c8aab797`.

**Production readiness is not established.** The Supabase production
migration ledger was inspected in the dashboard and showed
`202611150005_mfa_enforcement` as its latest recorded version. Repository
migrations `202611150006_scan_history_retention.sql` and
`202611170001`–`202611170004` were absent from the ledger. Deployed Edge
Function revisions were not verified. No SQL or Edge Function deployment was
performed. The Supabase dashboard displayed an active technical-issue banner
at the time of inspection.

The specialist static security review found no substantiated exploitable
vulnerabilities in the reviewed workspace. This is not a penetration test.
The [security audit](CYVORA_SECURITY_AUDIT.md) lists controls and unverified
areas.

## Current remediation update

The local workspace now includes the approved Android release-workflow
hardening, notification queue retry behavior, and encrypted notification
storage with explicit consent, configurable 1/7/30-day retention, expiry, and
user deletion. A completed scan is durably marked before queue cleanup, and
consent revocation clears queued previews. A local pgTAP suite covers RLS, family isolation, unauthorized RPC, invite
reuse/expiry, user-delete cascades, AI quota behavior, and notification scan
idempotency. Both suites passed against a disposable Supabase PostgreSQL
17.11.0.018 container after applying repository migrations through
`202611170007`. The base image needed test-only Auth and Storage schema
helpers; this was a direct `psql` run, not full Supabase CLI orchestration or
staging validation. No production database, GitHub settings, credentials, or
live providers were changed or accessed.

Latest local results: Flutter analysis passed; Flutter tests passed (66);
Supabase Node tests passed (94); Android release policy tests passed (15);
and a debug APK built successfully. PHP/Composer, Deno, iOS tooling, device
validation, and supported dependency advisory scanners were unavailable or
not configured. See [test results](CYVORA_TEST_RESULTS.md).

## Architecture and implementation status

| Area | Status | Evidence and remaining work |
|---|---|---|
| Flutter client and Supabase Auth | IMPLEMENTED; VERIFIED locally | Auth/MFA gate, dashboard, scan, family, alert, and settings flows exist. Current workspace analysis and 66 tests pass (the earlier 59-test baseline remains historical). |
| Backend boundary | IMPLEMENTED | `DashboardRepository` delegates Supabase reads and Edge Function requests; deterministic analysis is server-side. |
| Supabase production schema | DEPLOYMENT UNVERIFIED | The last ledger observation is historical. Migrations through `202611170007_notification_scan_reservation_initial_lease.sql` are in the repository and passed local PostgreSQL tests; current deployed versions were not checked. |
| Edge Function deployment | NOT TESTED | Current deployed revisions were not independently inspected. Source presence does not prove deployment. |
| Family Protection | PARTIALLY IMPLEMENTED; NOT TESTED live | Invite/revoke/accept and membership UI/code exist. Cross-family RLS, concurrent invitation quotas, and lifecycle need isolated database tests. Migration `202611170001` is not recorded in production. |
| AI guardrails | IMPLEMENTED in repository; NOT TESTED against PostgreSQL/live providers | Daily request limits, deduplication/cooldowns, leases, and circuit breaker are in source/migrations. Production migrations `202611170002`–`004` are absent from the observed ledger. Limits count requests, not provider spend. |
| Scam detection | PARTIALLY IMPLEMENTED; VERIFIED on a small fixture | Deterministic modules, evidence and risk schema, and optional AI/reputation integrations exist. The 14 synthetic examples are regression checks, not a real-world accuracy estimate. |
| Android notification monitoring | PARTIALLY IMPLEMENTED; DEVICE TESTING REQUIRED | Previews are opt-in, Keystore-encrypted, expire after configurable retention, and can be deleted. Manual review retains failed items for retry; server idempotency migrations and pgTAP behavior pass locally. Device/OEM, permission-revocation, force-stop, and reboot behavior are unverified. |
| Android debug build | VERIFIED | `flutter build apk --debug --no-pub` passed locally after the notification changes. |
| Android release/signing | SOURCE HARDENED; OWNER CONFIGURATION REQUIRED | Stable-tag/default-branch checks, least-privilege jobs, gated signing/publishing environments, and draft publishing are implemented. GitHub protected rules, reviewers, secret placement, and signed release behavior were not verified. |
| iOS | BLOCKED for build/runtime verification | Bundle ID is `com.example.cyvoraMobile`, different from Android `com.example.cyvora_mobile`; no ID was changed. Xcode, signing, provisioning, privacy declarations, and device test were unavailable on Windows. |
| Laravel | PARTIALLY IMPLEMENTED | Laravel 13 scaffold exposes a default welcome route and example tests; no Cyvora integration contract was identified. Confirm its intended role. |
| CI | VERIFIED | GitHub Actions run 44035823882 succeeded for the inspected commit. CI does not execute PostgreSQL/RLS integration, live providers, iOS, or device notification tests. |

## Baseline checks

| Check | Result |
|---|---|
| `flutter analyze --fatal-infos` | PASS — no issues found |
| `flutter test --no-pub` | PASS — 59 tests |
| `node --experimental-strip-types --test .\supabase\tests\*.test.mjs` | PASS — 89 tests |
| `flutter build apk --debug --no-pub` | PASS — built debug APK; Gradle and SDK XML warnings were emitted |
| GitHub Actions CI | PASS — run 44035823882 for `c8aab797` |
| `php artisan test` | BLOCKED — PHP is not installed/on `PATH` |
| PostgreSQL migration/RLS tests | NOT TESTED — no `psql`/Supabase CLI; Docker engine unavailable |
| Deno Edge Function runtime tests | NOT TESTED — Deno unavailable |
| Live AI/URL provider requests | NOT TESTED — no credentials accessed or requests made |
| iOS build and device test | NOT TESTED — Xcode unavailable on Windows |
| Android physical/HarmonyOS test | NOT TESTED — no device crash log/device validation |

See [detailed test results](CYVORA_TEST_RESULTS.md).

## Current remediation checks

| Check | Result |
|---|---|
| Flutter analysis | PASS — no issues |
| Flutter tests | PASS — 66 |
| Supabase Node tests | PASS — 94 |
| Release-ref, artifact-version, and workflow policy tests | PASS — 15 |
| Android debug build | PASS — APK built |
| `supabase/tests/security_boundaries.test.sql` | PASS — 13 pgTAP assertions on disposable local Supabase PostgreSQL |
| `supabase/tests/notification_scan_idempotency.test.sql` | PASS — 14 pgTAP assertions on disposable local Supabase PostgreSQL |
| Dependency advisory scans | NOT RUN — Dart audit command unavailable; PHP/Composer unavailable; no Laravel npm lockfile |

## Prioritized release blockers

1. **Database/schema alignment:** validate pending migrations in isolated
   staging, in timestamp order (`202611150006`, then `202611170001`–`007`).
   Local pgTAP suites pass, but run RPC, RLS, family isolation, and true
   multi-session concurrency tests before any production change.
2. **Confirm deployed Edge Functions:** verify the actual revisions and
   ensure they match the database schema before enabling optional AI or
   relying on family invitation creation.
3. **Confirm app identities:** owner must approve canonical Android/iOS
   identifiers and release/signing history. Do not change them before
   approval.
4. **Notification privacy and reliability:** test encrypted storage and
   retention on devices, including permission revocation, key recovery,
   process death, expiry, and deletion. Validate the server-side minimizer for
   optional AI provider input; it is heuristic and not on-device redaction.
5. **Scam evaluation:** expand the reviewed Filipino/Taglish and English
   corpus, measure held-out precision/recall/F1/false positives, and establish
   review/release gates.
6. **iOS verification:** build/sign/test on macOS/Xcode after identity and
   provisioning are confirmed.
7. **Laravel decision:** document the intended service boundary or explicitly
   retain it as an unused scaffold.
8. **Operational checks:** configure provider-side spend limits and verify
   provider model availability, plan terms, retention, and rate limits in
   staging. Request quotas do not guarantee a monetary cap.

## Manual actions and safety

- Create or identify an isolated staging Supabase project; no staging branch
  was visible during the dashboard inspection.
- Apply and test migrations in staging, then verify the resulting ledger and
  deployed function revisions. Do not infer deployment from Git presence.
- Obtain owner approval and a reviewed deployment plan before production
  migrations, Edge Function deployments, identity changes, or signing changes.
- Configure GitHub Environments `android-signing` and `android-publish` with
  required reviewers, move signing secrets to `android-signing`, and protect
  the default branch and stable `v*` tags. The source workflow cannot enforce
  missing repository-level rules by itself.
- Keep provider/service-role keys in server-side secret storage. No secrets
  were read or changed during this audit.
- Obtain redacted HarmonyOS crash logs before diagnosing the reported startup
  failure; do not infer a root cause without device evidence.

## Related audit records

- [Full code audit](CYVORA_FULL_CODE_AUDIT.md)
- [Security audit](CYVORA_SECURITY_AUDIT.md)
- [Architecture map](CYVORA_ARCHITECTURE.md)
- [Test results](CYVORA_TEST_RESULTS.md)
