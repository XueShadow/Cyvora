# Cyvora Authentication Test Report — Phase 1

## Validation results

| Command/check | Result | Evidence / boundary |
|---|---|---|
| `flutter pub get --enforce-lockfile` (from `flutter/`) | PASS | Dependencies resolved against the existing lockfile; no manifest/lockfile edits. |
| `flutter analyze` (from `flutter/`) | PASS | No issues found. |
| `flutter test` (from `flutter/`) | PASS | 88 tests passed, including auth error mapping, form validation, duplicate submission, recovery, MFA UI, and regression tests. |
| `flutter build apk --debug --no-pub` (from `flutter/`) | PASS | Android debug APK built successfully. |
| `flutter build web --no-pub` (from `flutter/`) | PASS | Web build completed successfully. |
| `node --test supabase/tests/*.test.mjs` | PASS | 107 tests passed, including source/mock MFA and authorization boundary tests. Not live Supabase integration. |
| `php artisan test --filter=SuperAdmin` (from `laravel/`) | PASS | 20 tests, 112 assertions. Supabase HTTP calls are faked. |
| Supabase migration validation / pgTAP | BLOCKED | Supabase CLI and `psql` are unavailable; Docker is installed but its daemon is not running. |
| Live Supabase Auth email/session/MFA tests | BLOCKED | No authorized staging project/credentials; no production account or database was used. |

## Requested case coverage

| Area | Case | Status | Test evidence / limitation |
|---|---|---|---|
| Registration | Valid registration and confirmation-required result | PASS | Presenter fake verifies submitted names/policy versions and confirmation address; no account was created. |
| Registration | Invalid email, weak password, missing names, password mismatch, missing consent | PASS | Flutter widget validation tests. |
| Registration | Duplicate submission | PASS | Delayed login keyboard-submit test exercises the shared in-flight submit guard. |
| Registration | Consent metadata and role assignment | PASS (source/mock) | Presenter delegates policy versions; data source sends consent timestamps/versions and no role. No live signup payload was captured. |
| Login | Successful login | PASS (mock) | Delayed repository test completes a login without duplicate request. |
| Login | Invalid credentials, unverified email, network, rate limit, temporary service error | PASS (mapper) | Typed Supabase error mapping tests; no hosted Auth call. |
| Login/session | Session restoration after restart, account switching, refresh-token failure | NOT TESTED | Supabase owns storage/refresh; no device/browser restart with a hosted session. |
| Login/session | Expired session handling | PASS (mapper) | Known expired-session code maps to sign-in-safe copy; actual token expiry was not exercised. |
| Logout | Local session clearing | NOT TESTED | Source uses Supabase `signOut()` whose SDK default is local scope; no live persisted session was available. |
| Recovery | Reset request and non-enumerating failure | PASS (mock/mapper) | Presenter and mapper fakes; no email was sent. |
| Recovery | Recovery callback / invalid PKCE callback state | PASS (widget/mapper) | Callback recovery screen and safe PKCE failure tests; no real deep link was opened. |
| Recovery | Expired/reused/malformed link | PASS (mapper only) | Expiry and missing-flow errors map safely; reused/malformed hosted links remain untested. |
| Recovery | Successful/failed password update | PASS (mock/mapper) | Presenter fake and expired-recovery failure tests; no real account password was updated. |
| MFA | Verified TOTP/SMS UI, invalid code, expired challenge, resend cooldown | PASS (mock/mapper) | Flutter MFA/widget and mapping tests. No real factor or SMS provider. |
| MFA | Missing privileged factor | PASS (UI) | Empty verified-factor test remains blocked from continuing. |
| MFA | Privileged AAL1 rejection / AAL2 acceptance; role enforcement | PASS (mock) | Supabase Node source tests and Laravel fake-HTTP tests; not deployed-policy verification. |
| MFA | Regular-user opt-in behavior | PASS (source/mock) | Supabase Node MFA tests. |
| Authorization | User reads own row but not another user's row; anonymous/invalid JWT; RLS AAL2 | BLOCKED | SQL boundary test exists but cannot run without local Supabase/PostgreSQL. Source inspection alone is not a pass. |
| Authorization | User metadata role escalation | PASS (mock) | Laravel Super Admin test verifies `user_metadata.role` cannot grant admin access; Node MFA tests also cover client-controlled metadata. |

## Test additions

- `flutter/test/authentication_error_message_test.dart`: safe classification,
  recovery/session expiry, MFA failures, and account-enumeration responses.
- `flutter/test/auth_screen_submission_test.dart`: repeated keyboard submit,
  sanitized unexpected failure, and loading-state cleanup.
- Expanded `flutter/test/auth_presenter_test.dart`: reset/update success and
  failure outcomes.
- Expanded `flutter/test/mfa_challenge_screen_test.dart`: post-verification
  callback and cooldown blocking.
- Expanded `flutter/test/widget_test.dart`: removal of inert Remember Me and
  password mismatch validation.

## Interpretation

PASS means the named local unit/widget or mocked test passed. It does not imply
live Supabase behavior. BLOCKED means required local infrastructure or hosted
access was unavailable. NOT TESTED means no direct runtime test was performed.
No live integration, deployed RLS, or production verification is claimed.

## Final verdict

**AUTHENTICATION NOT READY.** Local Flutter, Supabase source/mock, and Laravel
mocked checks passed, but isolated PostgreSQL/RLS verification and hosted
Supabase Auth, redirect, email-delivery, session, and MFA checks remain blocked.
