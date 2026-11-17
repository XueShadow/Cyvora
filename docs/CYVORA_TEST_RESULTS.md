# Cyvora test results

## Current remediation verification

The following checks ran after the local Android-release and notification
privacy/reliability changes. They are workspace results, not production
verification.

| Check | Result | Notes |
|---|---|---|
| `flutter analyze --fatal-infos` | **PASS** | No issues found. |
| `flutter test --no-pub` | **PASS — 66 tests** | Includes queue retry/duplicate suppression, durable completion-before-cleanup ordering, consent, retention, and deletion MethodChannel coverage. |
| `node --experimental-strip-types --test supabase/tests/*.test.mjs` | **PASS — 96 tests** | Mocked provider flows and static migration-contract assertions; not PostgreSQL integration. |
| `python -m unittest discover -s flutter/scripts -p "test_*.py"` | **PASS — 15 tests** | Release-ref, tag/artifact version, and workflow policy tests. This is now the release workflow's test command. |
| `flutter build apk --debug --no-pub` | **PASS** | Built `flutter/build/app/outputs/flutter-apk/app-debug.apk`; Gradle and Android SDK XML warnings were emitted. |
| `supabase/tests/security_boundaries.test.sql` | **PASS — 13 pgTAP assertions** | Run via `psql` against a disposable Supabase PostgreSQL 17.11.0.018 container after applying repository migrations. Covers RLS, family access, RPC permissions, invitation lifecycle, deletion cascade, and AI quota checks. |
| `supabase/tests/notification_scan_idempotency.test.sql` | **PASS — 14 pgTAP assertions** | Same disposable database; covers reservation, duplicate blocking, replay, retry, deletion tombstones, and cleanup scheduling. |
| Notification reservation separate-session checks | **PASS — 7/7** | Independent PostgreSQL sessions verified contention, expired lease recovery, retry, completed replay, user isolation, RPC authorization, and rollback after transaction failure; not repeated in this pass. |
| Migration reapplication and catalog checks | **PASS** | Reapplied migrations 005–007 after all 24 migrations; no public tables without RLS and no public `SECURITY DEFINER` functions without fixed `search_path`. |
| `node --test .\supabase\tests\scam-evaluation.test.mjs` | **PASS — 26 synthetic examples** | 13 TP, 13 TN, 0 FP/FN; six paired scam categories; not real-world performance evidence. |
| User-provided Docker Scout screenshot | **REVIEWED, NOT REPRODUCED** | Five visible Medium CVEs, but the image reference/digest and package versions are missing; not attributed to a Cyvora artifact. See `CYVORA_DOCKER_IMAGE_ANALYSIS.md`. |
| `dart pub audit` | **UNAVAILABLE** | The installed Dart SDK has no `pub audit` subcommand. |
| PHP/Composer audit and Laravel tests | **BLOCKED** | PHP and Composer are not installed/on `PATH`. |
| Live provider, deployed database, device/OEM, and iOS validation | **NOT TESTED** | No credentials, production systems, or devices were used. |

The SQL suites ran against a disposable Supabase PostgreSQL image using direct
`psql`, not `supabase test db` or a fully started local Supabase stack. The
base database image required test-only Auth and Storage schema helpers. All
repository migrations through `202611170007` were applied; SQL fixtures rolled
back. Separate-session reservation checks were performed in the previous
validation pass. This does not verify a hosted staging/production project,
Supabase CLI orchestration, family/AI quota concurrency, or deployed Edge
Function behavior.

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

The synthetic fixture now contains 26 examples: 13 scam-like and 13
legitimate, including paired bank/OTP, government, delivery, romance,
brand-lookalike, and Unicode-homograph cases. It reported 13 true positives,
13 true negatives, 0 false positives, and 0 false negatives for this fixture.
Precision, recall, specificity, F1, and accuracy are 1.0 on these synthetic
examples only. The cases are not a representative or held-out corpus and do
not estimate real-world performance. A reviewed Filipino/Taglish corpus and
independent held-out evaluation are still needed.

## Interpretation

The local Flutter, backend, and Android debug checks pass. These results do
not verify production deployment, database permissions, migration
transaction/concurrency behavior, live provider compatibility, Android
background behavior, or iOS readiness. No production database, credentials,
or signing identity were changed.
