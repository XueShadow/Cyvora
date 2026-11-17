# Cyvora security audit

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

- Android notification previews are stored in app-private
  `SharedPreferences`; the queue has a maximum item count but no verified
  time-based retention or application-layer encryption. Review the
  device-threat model and add explicit retention/clear controls before claiming
  encryption-at-rest protection.
- Notification analysis is user-initiated rather than automatic. The selected
  queue item is removed before the scan completes; a failed scan can therefore
  lose that preview.
- AI and URL reputation integrations may share minimized scan data or the
  submitted URL with third parties after user selection. Provider retention,
  pricing, and current model availability were not independently verified.
- Request-count limits are not monetary spend limits.

## Verification still required

| Area | Status | Required evidence |
|---|---|---|
| Production RLS and family isolation | NOT TESTED | Run separate-user authorization and cross-family tests in isolated staging. |
| Database RPC permissions and concurrency | NOT TESTED | Execute migrations on PostgreSQL and test concurrent quota/invitation requests, cooldowns, leases, and circuit recovery. |
| Production schema alignment | PARTIALLY VERIFIED | Dashboard ledger showed latest entry `202611150005_mfa_enforcement`; `202611150006` and `202611170001`–`202611170004` were absent. Edge Function deployment revisions remain unknown. |
| Supabase Auth/MFA settings | NOT TESTED | Verify redirect allowlists, session settings, MFA enrollment policy, rate limits, and SMS delivery in the project dashboard. |
| Provider runtime secrets and model calls | NOT TESTED | Owner verifies server-side configuration in staging; no credentials were read and no live calls were made. |
| Android storage/retention behavior | NOT TESTED | Test consent, revocation, clearing, and retention on supported Android and OEM devices. |
| iOS runtime/privacy | NOT TESTED | Build and test on macOS/Xcode; verify signing, bundle identity, URL callbacks, and privacy declarations. |
| Laravel production configuration | NOT TESTED | Confirm whether this scaffold is deployed or intended to process Cyvora data. |

No production changes were made. See
[production readiness](CYVORA_PRODUCTION_READINESS.md) for deployment gates.
