# Cyvora production readiness

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
consent revocation clears queued previews. A local pgTAP suite was prepared
for RLS, family isolation, unauthorized RPC, invite reuse/expiry, user-delete
cascades, and AI quota behavior, but it was not run because Supabase CLI,
PostgreSQL, and Docker were unavailable. No production database, GitHub
settings, credentials, or live providers were changed or accessed.

Latest local results: Flutter analysis passed; Flutter tests passed (64);
Supabase Node tests passed (90); Android release/ref/artifact/workflow policy
tests passed (15); and a debug APK built successfully. PHP/Composer, Deno, iOS
tooling, device validation, and supported dependency advisory scanners were
unavailable or not configured. See [test results](CYVORA_TEST_RESULTS.md).

## Architecture and implementation status

| Area | Status | Evidence and remaining work |
|---|---|---|
| Flutter client and Supabase Auth | IMPLEMENTED; VERIFIED locally | Auth/MFA gate, dashboard, scan, family, alert, and settings flows exist. Current workspace analysis and 64 tests pass (the prior 59-test baseline remains recorded below). |
| Backend boundary | IMPLEMENTED | `DashboardRepository` delegates Supabase reads and Edge Function requests; deterministic analysis is server-side. |
| Supabase production schema | PARTIALLY VERIFIED; DEPLOYMENT REQUIRED | Ledger ends at `202611150005_mfa_enforcement`; `202611150006` and `202611170001`–`202611170004` are not recorded. |
| Edge Function deployment | NOT TESTED | Current deployed revisions were not independently inspected. Source presence does not prove deployment. |
| Family Protection | PARTIALLY IMPLEMENTED; NOT TESTED live | Invite/revoke/accept and membership UI/code exist. Cross-family RLS, concurrent invitation quotas, and lifecycle need isolated database tests. Migration `202611170001` is not recorded in production. |
| AI guardrails | IMPLEMENTED in repository; NOT TESTED against PostgreSQL/live providers | Daily request limits, deduplication/cooldowns, leases, and circuit breaker are in source/migrations. Production migrations `202611170002`–`004` are absent from the observed ledger. Limits count requests, not provider spend. |
| Scam detection | PARTIALLY IMPLEMENTED; VERIFIED on a small fixture | Deterministic modules, evidence and risk schema, and optional AI/reputation integrations exist. The 14 synthetic examples are regression checks, not a real-world accuracy estimate. |
| Android notification monitoring | PARTIALLY IMPLEMENTED; DEVICE TESTING REQUIRED | Previews are opt-in, Keystore-encrypted, expire after a configurable retention period, and can be deleted. Manual review retains failed items for retry; device/OEM, permission-revocation, force-stop, and reboot behavior are unverified. |
| Android debug build | VERIFIED | `flutter build apk --debug --no-pub` passed locally after the notification changes. |
| Android release/signing | SOURCE HARDENED; OWNER CONFIGURATION REQUIRED | Stable-tag/default-branch checks, least-privilege jobs, gated signing/publishing environments, and draft publishing are implemented. GitHub protected rules, reviewers, secret placement, and signed release behavior were not verified. |
| iOS | BLOCKED for build/runtime verification | Bundle ID is `com.example.cyvoraMobile`, different from Android `com.example.cyvora_mobile`; no ID was changed. Xcode, signing, provisioning, privacy declarations, and device test were unavailable on Windows. |
| Laravel Super Admin panel | NOT IMPLEMENTED; RELEASE BLOCKER | The owner confirms this is the intended admin panel, but Laravel currently has only the welcome route and development tooling. There is no admin authentication, RBAC, dashboard, or Supabase data boundary. Do not expose production user data until these are implemented and tested. |
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
| Flutter tests | PASS — 64 |
| Supabase Node tests | PASS — 90 |
| Release-ref, artifact-version, and workflow policy tests | PASS — 15 |
| Android debug build | PASS — APK built |
| `supabase/tests/security_boundaries.test.sql` | PREPARED, NOT RUN — local database tooling unavailable |
| Dependency advisory scans | NOT RUN — Dart audit command unavailable; PHP/Composer unavailable; no Laravel npm lockfile |

## Prioritized release blockers

1. **Database/schema alignment:** validate pending migrations in isolated
   staging, in timestamp order (`202611150006`, then `202611170001`–`004`).
   Run RPC, RLS, family isolation, concurrency, lease-expiry, cooldown, and
   circuit-breaker tests before any production change.
2. **Confirm deployed Edge Functions:** verify the actual revisions and
   ensure they match the database schema before enabling optional AI or
   relying on family invitation creation.
3. **Confirm app identities:** owner must approve canonical Android/iOS
   identifiers and release/signing history. Do not change them before
   approval.
4. **Notification privacy and reliability:** test encrypted storage and
   retention on devices, including permission revocation, key recovery,
   process death, expiry, and deletion. Implement local redaction for
   personally identifying data/OTPs before optional external provider calls.
5. **Scam evaluation:** expand the reviewed Filipino/Taglish and English
   corpus, measure held-out precision/recall/F1/false positives, and establish
   review/release gates.
6. **iOS verification:** build/sign/test on macOS/Xcode after identity and
   provisioning are confirmed.
7. **Laravel Super Admin:** define the trusted admin identity, role/permission
   matrix, Supabase access boundary, and audit-log requirements; then implement
   protected routes and role-separated tests. Laravel is an intended system
   component, not an unused scaffold.
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

## Follow-up assessment — 2026-11-23

**Verdict: NOT PRODUCTION READY.** The current local APK and AAB build, but
both signatures fail the expected certificate identity check configured in
the release validator. The repository release workflow runs that validator,
but its protected CI signing secret was not accessed; the CI signing identity
and release outcome are therefore unverified. The owner must confirm which
signing identity is authorized and supply the matching signing configuration;
changing the validator's expected identity is not a safe workaround.

The current worktree is at commit
`3d8ed60c450db25e02f754f408e41f25dc1282db` on
`fix/mlkit-release-crash`. It was already dirty before this follow-up. No
source, signing, production database, GitHub, or provider configuration was
changed.

| Check | Current result |
|---|---|
| Flutter analysis / Flutter tests | PASS / PASS (64) |
| Supabase Node tests | PASS (90); mocks/static assertions, not PostgreSQL |
| Android release policy tests | PASS (15) |
| Laravel tests / Composer validation | PASS (2) / PASS |
| Android debug, release APK, release AAB builds | PASS |
| APK and AAB signature validity | PASS |
| APK/AAB identity against the validator's expected production certificate | **FAIL** — both use the same different signer |
| PostgreSQL migration/RLS integration and current deployed migration ledger | NOT TESTED / NOT RE-VERIFIED |
| Deno Edge Function runtime and live provider calls | NOT TESTED |
| iOS build/signing | BLOCKED — Xcode unavailable on Windows |
| Physical Android notification behavior | NOT TESTED — no Android device connected |

The worktree's new `202611230001_preserve_scan_history.sql` cancels the
scheduled scan-history cleanup job and drops its function. The corresponding
client-side 120-day deletion was removed and the privacy statement now says
scan history remains until user or account deletion. This behavior is
internally aligned in source but has not been exercised against PostgreSQL or
verified in a deployed project. The last production ledger observation was
2026-11-17, so it cannot establish the current deployment state.

Next gates:

1. Owner confirms the authorized Android release certificate; use the matching
   protected signing material and rerun release artifact validation.
2. Verify migrations, including the scan-history change, in isolated staging;
   run the separate-account RLS and family lifecycle suite before any
   production change.
3. Verify deployed Edge Function revisions and provider configuration in
   staging without exposing credentials.
4. Perform physical-device notification and iOS validation on supported
   hardware/toolchains.

See [follow-up test results](CYVORA_TEST_RESULTS.md),
[security follow-up](CYVORA_SECURITY_AUDIT.md), and the
[remediation log](CYVORA_REMEDIATION_LOG.md).

### Laravel Super Admin follow-up

The current Laravel test suite has two passing scaffold tests, but no
authentication, admin routes, RBAC, dashboard, or Supabase connection exists
to exercise. `php artisan route:list` showed no admin/login/logout routes.
`SESSION_SECURE_COOKIE` now defaults on for production via
`laravel/config/session.php`; the local default and explicit override remain
supported. A development-only Boost browser-log endpoint is registered in the
development environment; production dependency installation and route absence
must be verified separately. Role-separated tests and data-isolation tests
remain blocked until the admin implementation and its permission model are
defined.
