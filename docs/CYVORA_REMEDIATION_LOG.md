# Cyvora remediation log

## 2026-11-23 follow-up

**Revision:** `3d8ed60c450db25e02f754f408e41f25dc1282db`
(`fix/mlkit-release-crash`).

The worktree contained pre-existing edits when this follow-up began. Those
changes were preserved. This follow-up made documentation changes only; it
did not edit application source, alter signing configuration, apply migrations,
access production credentials, or deploy anything.

| Priority | Finding / root cause | Affected files | Action and status |
|---|---|---|---|
| HIGH — local release blocker | Local Android release APK and AAB signatures verify, but neither matches the expected certificate identity required by `validate()` in the release validator. The local signing configuration and repository expectation are inconsistent. The protected CI signing secret was not accessed, so CI signing remains unverified. | `flutter/android/app/build.gradle.kts`; `flutter/scripts/validate_android_release.py` (`verify_apk_signature()`, `verify_aab_signature()`, `validate()`); `.github/workflows/android-release.yml` | Confirmed by building both artifacts, independently verifying their signatures without exposing certificate details, and running the release artifact validator. **Blocked:** owner must confirm the authorized identity and verify both local and protected CI signing configurations. No fingerprint or signing material was changed. |
| MEDIUM — deployment/privacy verification | The current worktree removes the 120-day scan-history cleanup path from `SupabaseDashboardRepository.loadScanHistory()` and adds a migration that unschedules the cleanup job and drops its function. User-facing privacy copy now states history remains until user or account deletion. Database behavior and deployment are not verified. | `flutter/lib/dashboard/dashboard_repository.dart`; `flutter/lib/auth_screen.dart`; `supabase/migrations/202611230001_preserve_scan_history.sql` (`public.delete_expired_scan_history()`) | Source and migration were inspected; no production or staging database was modified. Verify the migration and deletion lifecycle in isolated PostgreSQL/Supabase staging before deployment. |
| HIGH — unresolved production assurance | RLS/family isolation, current schema/function alignment, and live provider behavior need database/runtime evidence unavailable in this environment. | `supabase/migrations/`; `supabase/functions/`; `supabase/tests/security_boundaries.test.sql` | Existing SQL integration suite was inspected but not run. Supabase CLI, `psql`, Deno, and a running Docker engine were unavailable. Do not treat static SQL assertions or Node mocks as production integration evidence. |
| MEDIUM — platform verification | Android notification lifecycle and iOS support require device/toolchain testing. | `flutter/android/`; `flutter/ios/` | Android build and Flutter tests passed, but no Android device was connected and Xcode is unavailable on Windows. Device/OEM and iOS behavior remain unverified. |

## Verification completed

- Flutter analysis: PASS; Flutter tests: 64 PASS.
- Supabase Node suite: 90 PASS.
- Android release policy/ref/artifact tests: 15 PASS.
- Laravel tests: 2 PASS; Composer validation: PASS.
- Android debug APK, release APK, and release AAB builds: PASS.
- Android APK/AAB signatures: cryptographically valid; configured production
  signer identity check: FAIL.

See [test results](CYVORA_TEST_RESULTS.md) for exact commands and limitations,
[production readiness](CYVORA_PRODUCTION_READINESS.md) for required release
gates, and [the security audit](CYVORA_SECURITY_AUDIT.md) for the boundary
between confirmed findings and unverified risks.

## Laravel Super Admin review — 2026-11-23

The owner confirms Laravel is the intended Super Admin panel. The current
Laravel app remains a scaffold with no admin login, role/permission model,
protected admin routes, dashboard, or Supabase integration. There is no
confirmed exploitable vulnerability in the reviewed app code, but the absence
of these controls means no privileged administrative action should be exposed
to production data yet.

One narrow hardening change was applied to `laravel/config/session.php`:
session cookies default to `Secure` when `APP_ENV=production`, while local
development remains compatible with HTTP and `SESSION_SECURE_COOKIE` can
still explicitly override the default. Artisan checks confirmed local=false,
production=true, and explicit false override. No admin authentication,
authorization, database integration, or user/family-management functionality
was invented.

`php artisan route:list` showed five routes and no admin/login/logout routes.
Laravel Boost's development browser-log endpoint appears without middleware;
production inclusion was not checked, and `laravel/boost` is a development
dependency. Ensure the production install excludes development dependencies
and confirm the route is absent. The two Laravel tests do not test admin
security. Role-separated tests remain a blocker until the owner defines the
identity and permission model.
