# Cyvora security audit

> **Integration status update (2026-11-23):** This document's original audit
> and PostgreSQL results describe the historical security-branch snapshot and
> were not reproduced on the current integration branch. The integration
> retains privileged MFA enrollment/AAL2 enforcement, the `super_admin` role,
> and the official Laravel Super Admin panel. Current local results are 102
> Supabase Node tests, 70 Flutter tests, Flutter analysis, 15 Android release
> policy tests, and an Android debug build. PostgreSQL/pgTAP was not run because
> the Docker daemon and `psql` were unavailable; hosted state, live providers,
> repository-owner settings, and device behavior remain unverified. See
> [current test results](CYVORA_TEST_RESULTS.md),
> [branch integration audit](CYVORA_BRANCH_INTEGRATION_AUDIT.md), and
> [Super Admin guide](CYVORA_SUPER_ADMIN_GUIDE.md).

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
| Laravel Super Admin controls | IMPLEMENTED ON FIX/INTEGRATION; DEPLOYMENT NOT VERIFIED | Laravel is the official separate admin panel. This security-branch audit snapshot predates its implementation; current source and test results are documented in `CYVORA_SUPER_ADMIN_GUIDE.md` and `CYVORA_TEST_RESULTS.md`. |

No production changes were made. See
[production readiness](CYVORA_PRODUCTION_READINESS.md) for deployment gates.

## Follow-up — 2026-11-23

The prior specialist review was performed against the 2026-11-17 repository
baseline. This follow-up did not run a penetration test or independently
re-review every unchanged file. No new exploitable vulnerability was
substantiated in the areas checked.

The Android release artifacts built from the current worktree have valid APK
and AAB signatures, but both use a signer that fails the expected production
identity check in `flutter/scripts/validate_android_release.py`. This is a
confirmed local release-integrity/configuration blocker, not evidence of key
compromise. The protected CI signing secret was not accessed, so the CI
release identity is unverified. The local signing configuration is ignored
by Git; no key values or actual signer fingerprint are included in this
report. Resolve it only with the owner's confirmed signing identity; do not
alter the validator's expected identity to bypass the gate.

The current worktree also changes scan-history retention: it removes the
client-side 120-day cleanup and adds a migration to cancel the scheduled
cleanup job and drop its database function. The privacy copy now states
history remains until user deletion or account deletion. This is a privacy
and deployment behavior change, not a confirmed vulnerability. PostgreSQL
execution, account-deletion behavior, and production migration state were not
verified.

Current Flutter, Node, Laravel, and Android build checks are summarized in
[test results](CYVORA_TEST_RESULTS.md). Separate-account RLS tests, database
migration execution, device behavior, and deployed configuration remain
unverified; the earlier static observations must not be treated as production
security certification.

## Laravel Super Admin review — 2026-11-23

This historical route/test inventory was performed against a branch snapshot
that did not include the Laravel implementation on `fix/mlkit-release-crash`.
The integration branch includes the official Super Admin panel; the earlier
statement that the panel was unimplemented is superseded. Current source-level
coverage and validation status are in `CYVORA_SUPER_ADMIN_GUIDE.md` and
`CYVORA_TEST_RESULTS.md`. Production installation mode, hosted configuration,
and deployed route inventory remain unverified.