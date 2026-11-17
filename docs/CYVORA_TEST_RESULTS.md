# Cyvora test results

## Current remediation verification

The following checks ran after the local Android-release and notification
privacy/reliability changes. They are workspace results, not production
verification.

| Check | Result | Notes |
|---|---|---|
| `flutter analyze --fatal-infos` | **PASS** | No issues found. |
| `flutter test --no-pub` | **PASS — 64 tests** | Includes queue retry/duplicate suppression, durable completion-before-cleanup ordering, consent, retention, and deletion MethodChannel coverage. |
| `node --experimental-strip-types --test supabase/tests/*.test.mjs` | **PASS — 90 tests** | Mocked provider flows and static migration-contract assertions; not PostgreSQL integration. |
| Android release policy tests | **PASS — 15 tests** | Release-ref, tag/artifact version, and workflow policy tests run from `flutter/scripts`. |
| `flutter build apk --debug --no-pub` | **PASS** | Built `flutter/build/app/outputs/flutter-apk/app-debug.apk`; Gradle and Android SDK XML warnings were emitted. |
| `supabase/tests/security_boundaries.test.sql` | **PREPARED (13 assertions), NOT RUN** | Supabase CLI, PostgreSQL, and Docker were unavailable. It includes RLS, family access, unauthorized RPC, expired/reused invite, deletion cascade, and AI quota checks. |
| `dart pub audit` | **UNAVAILABLE** | The installed Dart SDK has no `pub audit` subcommand. |
| PHP/Composer audit and Laravel tests | **BLOCKED** | PHP and Composer are not installed/on `PATH`. |
| Live provider, deployed database, device/OEM, and iOS validation | **NOT TESTED** | No credentials, production systems, or devices were used. |

An attempted Python test import from the repository root failed because the
script directory was not on the module path. Rerunning from `flutter/scripts`
passed all seven tests; this was a command invocation issue, not a test failure.

## Original baseline

**Run date:** 2026-11-17
**Repository baseline:** `c8aab7970b30216a6477f6bd61486ce9d71c7a22`
**Purpose:** Audit-only baseline; no source files were changed.

## Checks run

| Check | Result | Notes |
|---|---|---|
| `flutter analyze --fatal-infos` | **PASS** | No issues found. |
| `flutter test --no-pub` | **PASS — 59 tests** | Dashboard, auth/MFA, scan, history, family, consent, and responsive-layout widget coverage. |
| `node --experimental-strip-types --test .\\supabase\\tests\\*.test.mjs` | **PASS — 89 tests** | Includes mocked provider flows and static migration-contract assertions; not PostgreSQL integration. |
| `flutter build apk --debug --no-pub` | **PASS** | Built `flutter/build/app/outputs/flutter-apk/app-debug.apk`. Gradle emitted Java native-access and Android SDK XML version warnings; build completed. |
| GitHub Actions CI run [44035823882](https://github.com/XueShadow/Cyvora/actions/runs/44035823882) | **PASS** | Commit `c8aab7970b30216a6477f6bd61486ce9d71c7a22`; CI workflow completed successfully. |
| `php artisan test` | **BLOCKED** | `php` is not installed/on `PATH`; Laravel tests did not run. |
| PostgreSQL migration execution and RLS integration | **NOT TESTED** | No `psql` or Supabase CLI was available. Docker CLI exists, but its Linux engine was not running. |
| Deno Edge Function runtime tests | **NOT TESTED** | Deno is not installed/on `PATH`. |
| Live AI/URL provider requests | **NOT TESTED** | No provider secrets were inspected and no third-party calls were made. |
| iOS build/device test | **NOT TESTED** | Xcode is unavailable on this Windows host. |
| Android physical/HarmonyOS test | **NOT TESTED** | No device crash log or live device test was available. |

## Scam evaluation fixture

The Node suite's synthetic fixture contains 14 examples: 7 scam-like and 7
legitimate. It reported 7 true positives, 7 true negatives, 0 false positives,
and 0 false negatives for this fixture (precision, recall, and accuracy 1.0).
This is a small regression fixture, not a statistically meaningful estimate
of real-world performance. A reviewed Filipino/Taglish corpus and held-out
evaluation are still needed.

## Interpretation

The local Flutter, backend, and Android debug checks pass. These results do
not verify production deployment, database permissions, migration
transaction/concurrency behavior, live provider compatibility, Android
background behavior, or iOS readiness. No production database, credentials,
or signing identity were changed.
