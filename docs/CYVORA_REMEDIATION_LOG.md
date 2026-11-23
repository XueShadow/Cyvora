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

This historical review inspected a branch snapshot that did not include the
Laravel implementation on `fix/mlkit-release-crash`. Its scaffold-only route
inventory and test conclusions do not describe the current integration
branch. Laravel is the official, separate Super Admin panel and is implemented
with protected routes, role/permission checks, server-side Supabase access,
and focused tests. Production Composer mode, hosted configuration, and
deployed route inventory remain unverified. The session-cookie `Secure`
default remains a defense-in-depth setting, not a substitute for deployment
verification.
