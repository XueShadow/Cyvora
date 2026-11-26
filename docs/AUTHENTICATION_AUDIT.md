# Cyvora Authentication Audit — Phase 1

## Scope and verdict

This audit follows the Flutter authentication flow, the related Supabase Auth
and RLS definitions, the configured Edge Function JWT boundary, and the Laravel
Super Admin session checks. No production account, database, Auth setting,
migration, or Edge Function was changed.

The local source review and automated checks pass. Hosted Supabase settings,
real email delivery, session restoration against Auth, and database-enforced
RLS/MFA behavior could not be verified in this environment. See the
[test report](./AUTHENTICATION_TEST_REPORT.md) and
[required Supabase configuration](./SUPABASE_AUTH_CONFIGURATION.md).

## Architecture and flow trace

`AuthScreen` → `AuthPresenter` → `AuthenticationRepository` →
`SupabaseAuthenticationRepository` → `SupabaseAuthDataSource` →
Supabase Auth. `AuthGate` observes Supabase auth events and only builds the
dashboard after its MFA gate has queried verified factors and session
assurance. Supabase owns session storage and refresh; Flutter does not persist
passwords or tokens itself.

| Flow | Implementation observed | Local evidence | External limitation |
|---|---|---|---|
| Registration | Validates email, strong password, confirmation, first/last name, and combined Terms/Privacy consent. Sends name, consent timestamps, and policy versions as user metadata; no role is sent. A missing session leads to the confirmation screen. | Widget and presenter tests pass. | No hosted signup or confirmation email was performed. |
| Email confirmation | Signup/resend use `authRedirectUrl`; the auth event mapper treats `passwordRecovery` separately. PKCE callback failure has a safe recovery path. | Callback widget and error-mapping tests pass; Android/iOS scheme declarations and Web origin behavior were inspected. | Dashboard allow-list, email template, and a real callback were not verified. |
| Resend confirmation | Uses Supabase `resend` with signup type. Failure responses are generic and do not disclose account status. | Error-mapping and presenter tests pass. | Provider delivery and rate limits were not tested live. |
| Login | Uses `signInWithPassword`; validation and duplicate-submit protection run before the presenter call. | Widget, presenter, and error-mapping tests pass. | No live credentials or hosted Auth session were used. |
| Logout/account switching | Calls Supabase `signOut()`; the installed SDK defaults to local scope. Signing out then entering another account is managed by Supabase Auth. | Source and SDK signature inspected; dashboard sign-out tests use fakes. | Local persistent-storage clearing and real account switching were not exercised. |
| Password reset/update | Reset uses `resetPasswordForEmail` with the configured redirect. Recovery events route to the new-password screen; update uses `updateUser`. Reset/resend success copy is generic. | Presenter and error-mapping tests cover success/failure, expired recovery state, and account-enumeration behavior. | No email delivery, link reuse/expiry, or real password update was performed. |
| Session restore/expiry | Supabase default storage and refresh are retained. The app maps known expired/missing-session errors to a sign-in message. | Expired-session mapping test passes. | App restart, refresh-token rotation/failure, and hosted expiry were not tested. |
| MFA | Flutter lists only verified TOTP/phone factors, creates a challenge, verifies the code, then reloads factors and assurance before opening the dashboard. Auth-state changes also trigger a recheck. | MFA screen, cooldown, safe error, and post-verification callback tests pass. | No real TOTP/SMS factor or AAL token was used. |
| Privileged accounts | Flutter reads only trusted `app_metadata` for UI routing. Supabase migrations require verified MFA and AAL2 for privileged roles. Laravel validates server-returned `app_metadata`, confirmation, token/session shape, and admin-directory role; it rechecks the user/session and MFA before protected requests. | Supabase Node tests and mocked Laravel Super Admin tests pass. | Database policies and hosted claims were not executed against PostgreSQL/Supabase. |

## Findings

| ID / severity | Affected files | Root cause | Fix applied | Test added | Test result | Remaining limitation |
|---|---|---|---|---|---|---|
| AUTH-01 / Medium | `flutter/lib/core/errors/authentication_error_message.dart`, `flutter/lib/core/errors/mfa_error_message.dart`, `flutter/lib/data/repositories/supabase_authentication_repository.dart`, `flutter/lib/features/authentication/models/authentication_repository.dart`, `flutter/lib/features/authentication/presenters/auth_presenter.dart`, `flutter/lib/features/authentication/views/auth_gate.dart`, `flutter/lib/features/authentication/views/auth_screen.dart`, `flutter/lib/features/authentication/views/mfa_challenge_screen.dart`, `flutter/lib/features/dashboard/views/dashboard_screen.dart` | Provider messages and arbitrary exception strings were propagated to UI; stream/MFA failures could show raw details. | Added centralized typed/status/code mapping, generic fallback, debug-only logging of operation plus exception type, and fixed safe account-deletion failure copy. No message or stack is logged or shown. | `authentication_error_message_test.dart`, `auth_presenter_test.dart`, `auth_screen_submission_test.dart`. | PASS; Flutter analyze PASS. | Unknown provider codes intentionally receive generic copy; live provider error variants were not exercised. |
| AUTH-02 / Medium | `flutter/lib/features/authentication/views/auth_gate.dart`, `flutter/lib/features/authentication/views/mfa_challenge_screen.dart` | The successful MFA callback cleared the challenge flag without refreshing factor state or checking current assurance. | Re-query verified factors and assurance after verification and on auth-state changes; keep the gate loading/closed during recheck and ignore stale async results. | `mfa_challenge_screen_test.dart`; existing Node/Laravel MFA tests. | PASS for local/mock tests. | Real AAL1→AAL2 transition and hosted RLS enforcement remain BLOCKED. |
| AUTH-03 / Low | `flutter/lib/features/authentication/views/auth_screen.dart` | “Remember me” toggled local UI state but did not change Supabase session persistence. | Removed the misleading control; Supabase remains responsible for its normal secure session persistence. | `widget_test.dart` absence assertion. | PASS. | Persistence still needs a staging restart test. |
| AUTH-04 / Low | `flutter/lib/features/authentication/views/auth_screen.dart` | Keyboard submission paths could invoke the same form action while an earlier request was active. | Added an `_isBusy` guard to submit and related email actions; reset requests hold the guard while the dialog/request is active. | `auth_screen_submission_test.dart`. | PASS. | No live provider concurrency/rate-limit test. |
| AUTH-05 / Low | `flutter/lib/features/authentication/views/auth_screen.dart` | Password-reset success wording implied delivery even though the client only receives request acceptance. | Changed success copy to conditional, enumeration-safe wording; failures remain generic for reset and resend. | `auth_presenter_test.dart`, `authentication_error_message_test.dart`. | PASS. | Actual delivery cannot be inferred from the client response; verify SMTP/provider logs in staging. |
| AUTH-06 / High (verification gate) | Supabase Dashboard URL/Auth/email/MFA settings; `flutter/lib/core/constants/supabase_config.dart`; Android/iOS callback declarations | Hosted redirect allow-list, confirmation enforcement, templates, providers, and MFA settings are external to this repository. | Documented the exact required dashboard setup; no external settings were changed. | No hosted test added; source declarations inspected. | Source inspection PASS; hosted verification BLOCKED. | Must be completed and tested in an isolated staging project before release. |
| AUTH-07 / High (verification gate) | `supabase/migrations/*` RLS/MFA policies and `supabase/tests/security_boundaries.test.sql` | SQL policies are source-visible but were not applied or exercised. | No production change. Local Node and Laravel tests cover mocked/source-level boundaries only. | Existing `security_boundaries.test.sql`; no new database test. | Node MFA suite and Laravel auth/authorization suite PASS; PostgreSQL/pgTAP BLOCKED. | Own-user/other-user, anonymous, invalid-JWT, and AAL2 policy behavior still needs isolated PostgreSQL/Supabase execution. |

## Security observations

- Signup metadata contains names and consent fields but no `role`. The Super
  Admin test suite verifies that `user_metadata.role` does not grant admin
  access. Server role assignment uses `app_metadata` and the admin directory.
- The reviewed profile, scan, alert, and admin policies are user/role scoped;
  selected profile/report/alert visibility is intentionally shared with
  verified family membership. This is source inspection, not proof of deployed
  RLS behavior.
- `mfa_access_allowed()` requires a verified factor and AAL2 for privileged
  roles. Laravel also refuses privileged sessions that lack verified MFA/AAL2.
- No Supabase service-role key was found in Flutter source.
- Do not treat Flutter role detection as authorization. Backend/RLS checks
  remain the security boundary.
