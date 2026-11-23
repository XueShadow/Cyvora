# Cyvora Testing and Validation

**Validation date:** 2026-11-17

**Environment:** Windows workspace. No production credentials, live provider
requests, or production database operations were used.

## Results

| Check | Result | Scope and limitation |
|---|---|---|
| `flutter analyze --fatal-infos` | PASS | No analyzer issues. |
| `flutter test --no-pub` | PASS — 64 tests | Includes notification queue success/failure, retry, duplicate suppression, durable completion-before-cleanup, and method-channel privacy controls. Does not execute Kotlin Keystore behavior. |
| `node --experimental-strip-types --test supabase/tests/*.test.mjs` | PASS — 90 tests | Mocked Edge/provider tests and migration source-contract checks. Does not execute PostgreSQL policies or migrations. |
| `python -m unittest test_validate_android_release_ref test_validate_android_release test_android_release_workflow` from `flutter/scripts` | PASS — 15 tests | Temporary Git repositories and local workflow/artifact policy checks. No signing secrets or GitHub APIs. |
| `flutter build apk --debug --no-pub` | PASS | Android debug APK built. Gradle/SDK warnings were emitted; no device install was performed. |
| `supabase/tests/security_boundaries.test.sql` | PREPARED — 13 pgTAP assertions; NOT RUN | Supabase CLI, PostgreSQL, and Docker were unavailable. Use only a disposable local Supabase test stack. |
| `dart pub audit` | UNAVAILABLE | The installed Dart SDK has no `pub audit` subcommand. |
| Dependency advisory scans | NOT RUN | No `osv-scanner`, Trivy, Snyk, Grype, PHP, or Composer was available; Laravel has no npm lockfile. |
| PHP/Laravel tests | BLOCKED | PHP and Composer unavailable. |
| Deno Edge Function runtime tests | BLOCKED | Deno unavailable. |
| Live providers, production RLS, migration ledger | NOT TESTED | No credentials or production access used. |
| Android device/OEM lifecycle, iOS/Xcode | NOT TESTED | No device or macOS/Xcode environment available. |

## Running local checks

```powershell
Set-Location flutter
flutter analyze --fatal-infos
flutter test --no-pub
flutter build apk --debug --no-pub

Set-Location ..\flutter\scripts
python -m unittest test_validate_android_release_ref test_validate_android_release test_android_release_workflow

Set-Location ..\..
node --experimental-strip-types --test supabase\tests\*.test.mjs
```

For PostgreSQL tests, start a disposable local Supabase stack and run
`supabase test db`. The test file wraps fixtures in a transaction and rolls
them back. Do not direct it at production. It checks scan RLS, family access,
cross-account writes, RPC execute permissions, invitation expiry and reuse,
user-deletion cascade, and AI quota reservation/exhaustion.

The pgTAP script does not create concurrent database sessions. True concurrent
invitation acceptance, invitation quota contention, and AI reservation races
still need separate multi-connection tests in a disposable local or isolated
staging environment.

## Interpretation and follow-up

- The Node suite reports 7 TP, 0 FP, 7 TN, and 0 FN on a 14-example synthetic
  evaluation fixture. These values are regression-fixture metrics, not
  real-world accuracy.
- Request-count limits protect provider request volume; they are not monetary
  spending limits. Configure spend caps with the providers.
- Android build success verifies compilation only. Keystore encryption,
  expiry alarms, permission revocation, key-loss recovery, process restart, and
  OEM background restrictions need device/instrumented testing.
- The static release workflow tests cannot prove the owner configured branch
  and tag rules, required Environment reviewers, or signing-secret placement.
- See [Security Remediation](./SECURITY_REMEDIATION_REPORT.md),
  [Production Readiness](./PRODUCTION_READINESS_REPORT.md), and
  [Release Security Guide](./RELEASE_SECURITY_GUIDE.md).

## Laravel Super Admin follow-up — 2026-11-23

- `php artisan test`: PASS, 2 tests; coverage is limited to the scaffold's
  public welcome route.
- `php artisan route:list --json`: 5 routes; no admin/login/logout routes.
  The current development install includes the Boost browser-log route.
- Session cookie configuration: verified with Artisan as false by default in
  local, true by default in production, and false when explicitly overridden.
- No admin authentication, RBAC, management routes, or Supabase integration
  exists yet, so role-separated authorization and admin data-isolation tests
  cannot be run.
- See the [security audit](./CYVORA_SECURITY_AUDIT.md) and
  [architecture diagram](./CYVORA_ARCHITECTURE.md).
