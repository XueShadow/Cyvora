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

## Architecture and implementation status

| Area | Status | Evidence and remaining work |
|---|---|---|
| Flutter client and Supabase Auth | IMPLEMENTED; VERIFIED locally | Auth/MFA gate, dashboard, scan, family, alert, and settings flows exist. Flutter analysis and 59 widget tests passed. |
| Backend boundary | IMPLEMENTED | `DashboardRepository` delegates Supabase reads and Edge Function requests; deterministic analysis is server-side. |
| Supabase production schema | PARTIALLY VERIFIED; DEPLOYMENT REQUIRED | Ledger ends at `202611150005_mfa_enforcement`; `202611150006` and `202611170001`–`202611170004` are not recorded. |
| Edge Function deployment | NOT TESTED | Current deployed revisions were not independently inspected. Source presence does not prove deployment. |
| Family Protection | PARTIALLY IMPLEMENTED; NOT TESTED live | Invite/revoke/accept and membership UI/code exist. Cross-family RLS, concurrent invitation quotas, and lifecycle need isolated database tests. Migration `202611170001` is not recorded in production. |
| AI guardrails | IMPLEMENTED in repository; NOT TESTED against PostgreSQL/live providers | Daily request limits, deduplication/cooldowns, leases, and circuit breaker are in source/migrations. Production migrations `202611170002`–`004` are absent from the observed ledger. Limits count requests, not provider spend. |
| Scam detection | PARTIALLY IMPLEMENTED; VERIFIED on a small fixture | Deterministic modules, evidence and risk schema, and optional AI/reputation integrations exist. The 14 synthetic examples are regression checks, not a real-world accuracy estimate. |
| Android notification monitoring | PARTIALLY IMPLEMENTED | Native notification listener queues previews and Flutter offers manual review; automatic background analysis and device/OEM verification are absent. |
| Android debug build | VERIFIED | `flutter build apk --debug --no-pub` passed locally. |
| Android release/signing | PARTIALLY VERIFIED; REQUIRES MANUAL ACTION | Production identity must be confirmed before a release. This audit did not build a new signed release or test install/update behavior. |
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
4. **Notification privacy and reliability:** choose retention/encryption
   requirements, make scanning behavior match the user-consent model, and
   test queue recovery and Android permission revocation on devices.
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
- Keep provider/service-role keys in server-side secret storage. No secrets
  were read or changed during this audit.
- Obtain redacted HarmonyOS crash logs before diagnosing the reported startup
  failure; do not infer a root cause without device evidence.

## Related audit records

- [Full code audit](CYVORA_FULL_CODE_AUDIT.md)
- [Security audit](CYVORA_SECURITY_AUDIT.md)
- [Architecture map](CYVORA_ARCHITECTURE.md)
- [Test results](CYVORA_TEST_RESULTS.md)
