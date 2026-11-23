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
| Laravel Super Admin controls | NOT IMPLEMENTED; NOT TESTED | The owner confirms Laravel is the intended panel, but no admin auth, RBAC, dashboard, or Supabase client exists. Implement and test before exposing user data. |

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

The read-only security review established no confirmed exploitable
vulnerability in the Laravel application. It did establish that the intended
Super Admin panel is not implemented: `routes/web.php` has only the public
welcome route; there is no login/logout, admin route, RBAC model, dashboard,
or Supabase client. `php artisan route:list` reported no admin or login routes.
The existing two Laravel tests cover only the scaffold and cannot establish
admin authorization, user/family isolation, CSRF handling for future mutations,
or audit logging. No role-separated authorization test was possible.

Laravel Boost registers a `POST /_boost/browser-logs` route with no middleware
in the current development installation. Boost is a development dependency;
whether production installs omit dev dependencies was not verified. Treat this
as a conditional deployment exposure, not a confirmed production
vulnerability. Verify `composer install --no-dev` and absence of the route in
the production route list.

`laravel/config/session.php` was hardened so the session cookie defaults to
`Secure` in production while remaining configurable. Local (`APP_ENV=local`),
production (`APP_ENV=production`), and explicit `SESSION_SECURE_COOKIE=false`
override behavior were checked using Artisan. This does not provide admin
authentication or replace TLS and deployment configuration.
