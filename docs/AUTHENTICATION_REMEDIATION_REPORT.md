# Cyvora Authentication Remediation Report — Phase 1

## Summary

Authentication-only changes were made. Registration/login validation, consent
metadata, Supabase-managed sessions, email confirmation, recovery callbacks,
TOTP/SMS support, server-assigned roles, and existing backend controls were
preserved. No UI redesign, production data change, migration deployment,
Edge Function deployment, commit, or push was performed.

## Remediation register

| ID | Severity | Affected file(s) | Root cause | Fix applied | Test added | Test result | Remaining limitation |
|---|---|---|---|---|---|---|---|
| AUTH-01 | Medium | [supabase_authentication_repository.dart](../flutter/lib/data/repositories/supabase_authentication_repository.dart), [auth_presenter.dart](../flutter/lib/features/authentication/presenters/auth_presenter.dart), [auth_gate.dart](../flutter/lib/features/authentication/views/auth_gate.dart), [auth_screen.dart](../flutter/lib/features/authentication/views/auth_screen.dart), [mfa_challenge_screen.dart](../flutter/lib/features/authentication/views/mfa_challenge_screen.dart), [authentication_error_message.dart](../flutter/lib/core/errors/authentication_error_message.dart) | Raw Supabase messages and `$error` strings reached UI; unexpected exceptions could escape the presenter. | Added one mapper for Supabase codes/statuses and operation context, mapped unexpected failures to safe copy, and limited diagnostics to operation and exception type in debug logs. | `authentication_error_message_test.dart`, `auth_presenter_test.dart`, `auth_screen_submission_test.dart`. | PASS; Flutter analyze PASS. | New provider error codes fall back safely but may need improved copy after staging observation. |
| AUTH-02 | Medium | [auth_gate.dart](../flutter/lib/features/authentication/views/auth_gate.dart), [mfa_challenge_screen.dart](../flutter/lib/features/authentication/views/mfa_challenge_screen.dart) | MFA verification success cleared the UI gate without confirming the new session assurance. | Reload factor list and Authenticator Assurance Level after verification; repeat recheck for auth-state events; keep protected content behind loading/failure states. | `mfa_challenge_screen_test.dart`; existing Node/Laravel AAL tests. | PASS for local/mock tests. | No real Supabase token transition or deployed RLS request was available. |
| AUTH-03 | Low | [auth_screen.dart](../flutter/lib/features/authentication/views/auth_screen.dart) | Remember Me was decorative and did not alter session behavior. | Removed the misleading control; no custom token/password storage was introduced. | `widget_test.dart` absence assertion. | PASS. | Supabase persistence still needs a staging restart test. |
| AUTH-04 | Low | [auth_screen.dart](../flutter/lib/features/authentication/views/auth_screen.dart) | Submit/resend/reset actions lacked a method-level in-flight guard. | Added `_isBusy` entry guards and held the reset guard for the dialog/request lifecycle. | `auth_screen_submission_test.dart`. | PASS. | Provider-side duplicate/rate-limit behavior is not live-tested. |
| AUTH-05 | Low | [auth_screen.dart](../flutter/lib/features/authentication/views/auth_screen.dart) | Reset success copy suggested the email was definitely delivered. | Replaced with generic conditional wording; reset/resend error responses do not disclose whether an account exists. | `auth_presenter_test.dart`, `authentication_error_message_test.dart`. | PASS. | Delivery must be confirmed through staging provider logs. |
| AUTH-06 | High — external gate | [supabase_config.dart](../flutter/lib/core/constants/supabase_config.dart), Android/iOS callback declarations, Supabase Dashboard | Email confirmation, redirect allow-list, SMTP, and MFA provider settings cannot be established from source alone. | Added [SUPABASE_AUTH_CONFIGURATION.md](./SUPABASE_AUTH_CONFIGURATION.md) with exact required settings; did not change the hosted project. | No hosted test added; source declarations inspected. | Source inspection PASS; hosted setup/test BLOCKED. | Requires an authorized isolated staging project and dashboard access. |
| AUTH-07 | High — external gate | Supabase RLS/MFA migrations and `supabase/tests/security_boundaries.test.sql` | SQL security boundaries have not been executed against PostgreSQL. | No schema change. Documented that source review and mocked tests are not runtime RLS verification. | Existing `security_boundaries.test.sql`; no new database test. | Supabase Node tests and Laravel mocked tests PASS; migration/pgTAP execution BLOCKED. | Run SQL security tests against isolated staging PostgreSQL before readiness approval. |

## Preserved controls and architecture

- Supabase continues to own session persistence and refresh.
- Registration still submits first/last name and consent timestamps/versions;
  the signup payload does not assign roles.
- Reset and resend responses are account-enumeration resistant.
- Password recovery remains a distinct Auth event and uses the configured
  redirect URI.
- Only verified TOTP/phone factors are offered for login MFA. The client
  re-reads current factor and assurance state before unlocking the dashboard.
- Privileged role/AAL2 enforcement remains server-side in Supabase policies,
  Edge Function guards, and Laravel Super Admin session checks.
- No service-role credential was added to Flutter.

## Current disposition

**Local remediation: PASS.**

**Staging readiness: BLOCKED** pending hosted redirect/confirmation/MFA
configuration and isolated live Auth/RLS tests. See the
[audit](./AUTHENTICATION_AUDIT.md) and
[test report](./AUTHENTICATION_TEST_REPORT.md).
