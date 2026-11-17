# Cyvora security audit

> **Current status update:** This audit began from the earlier repository
> baseline below. Notification queue encryption/retention and Android release
> workflow hardening have since been implemented in source. The queue retains
> failed items and supports retry; notification idempotency and security
> boundary suites pass locally (14 and 13 pgTAP assertions), and seven
> separate-connection reservation checks passed. All 24 repository migrations
> were applied locally; migrations 005–007 were reapplied. The tests ran via
> direct `psql` against a disposable Supabase PostgreSQL container, not hosted
> staging. Production migration state, GitHub owner settings, live providers,
> and device behavior remain unverified. An independent source/workflow
> review found no confirmed exploitable vulnerabilities. For current results, use
> [the complete security audit](CYVORA_COMPLETE_SECURITY_AUDIT.md) and
> [remediation report](CYVORA_REMEDIATION_REPORT.md).

**Audit date:** 2026-11-17
**Repository baseline:** `c8aab7970b30216a6477f6bd61486ce9d71c7a22`
**Method:** Read-only static review by the security-review agent, plus local
test execution. No secrets, production credentials, or user content were
accessed. This is not a penetration test or production certification.

## Security findings

The specialist static review reported **no substantiated exploitable
vulnerabilities** in the reviewed workspace. The following table is the
requested findings summary; it contains no vulnerability rows because none
were confirmed.

| # | Severity | File | Lines | Vulnerability | Confidence |
|---|----------|------|-------|---------------|------------|

## Safeguards observed in code

- Flutter uses Supabase Auth and the publishable key; provider and
  service-role credentials are intended to remain server-side.
- Protected Edge Functions manually validate bearer tokens and apply MFA
  checks before privileged operations.
- SQL migrations define RLS and service-role-only RPC permissions.
- Family invitations use random tokens, store hashes, have expirations, and
  require a verified matching email on consumption.
- Analysis request bodies are bounded. Deterministic checks remain available
  when optional AI providers are unavailable.
- AI provider calls are opt-in, limited to a primary and at most one fallback,
  require bounded request limits, and use validated structured responses.
- Private/reserved network destinations are excluded from external reputation
  checks.

These are source-level observations, not proof that the same code or schema is
deployed to production.

## Privacy and control gaps (not confirmed exploitable vulnerabilities)

- Android notification previews are stored with AES/GCM using Android Keystore
  and have 1/7/30-day retention and clear controls in source. Device hardware,
  key-loss, and OEM behavior remain unverified. No per-app exclusion or
  per-notification content-length cap was found.
- Notification analysis is user-initiated rather than automatic. The queue
  retains items on failure and supports retry in source; actual device process
  death/recovery remains unverified.
- AI and URL reputation integrations may share minimized scan data or the
  submitted URL with third parties after user selection. Provider retention,
  pricing, and current model availability were not independently verified.
- Request-count limits are not monetary spend limits.

## Verification still required

| Area | Status | Required evidence |
|---|---|---|
| Local RLS/RPC and notification reservation | PASS locally | Disposable database: 13 security-boundary and 14 idempotency pgTAP assertions plus 7 separate-connection reservation checks. Repeat on isolated hosted staging. |
| Database RPC permissions and concurrency | PARTIALLY VERIFIED | Notification reservation concurrency is verified locally; family-invitation and AI-quota concurrency, provider circuit behavior against live services, and hosted behavior remain unverified. |
| Hosted schema alignment | NOT VERIFIED | Historical dashboard evidence recorded `202611150005_mfa_enforcement`; this pass did not inspect a hosted migration ledger. Edge Function deployment revisions remain unknown. |
| Supabase Auth/MFA settings | NOT TESTED | Verify redirect allowlists, session settings, MFA enrollment policy, rate limits, and SMS delivery in the project dashboard. |
| Provider runtime secrets and model calls | NOT TESTED | Owner verifies server-side configuration in staging; no credentials were read and no live calls were made. |
| Android storage/retention behavior | NOT TESTED | Test consent, revocation, clearing, and retention on supported Android and OEM devices. |
| iOS runtime/privacy | NOT TESTED | Build and test on macOS/Xcode; verify signing, bundle identity, URL callbacks, and privacy declarations. |
| Laravel production configuration | NOT TESTED | Confirm whether this scaffold is deployed or intended to process Cyvora data. |

No production changes were made. See
[production readiness](CYVORA_PRODUCTION_READINESS.md) for deployment gates.
