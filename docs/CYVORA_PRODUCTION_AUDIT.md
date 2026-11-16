# Cyvora Production Readiness Audit

**Audit date:** 2026-11-17  
**Repository:** `XueShadow/Cyvora`  
**Inspected baseline:** `56da7a3` on `main`; current AI provider guardrail changes are local and uncommitted
**Production systems:** No production database, secrets, signing identity, or migrations were changed.

## Status key

- **PASS** — directly checked and successful.
- **FAIL** — a confirmed defect or requirement is not met.
- **PARTIALLY IMPLEMENTED** — source support exists, but an important requirement or verification remains incomplete.
- **NOT TESTED** — this environment could not execute the relevant test.
- **BLOCKED** — execution requires unavailable hardware, signing material, or external access.

## Executive summary

The existing Flutter + Supabase architecture is viable and does not need a rewrite. The current source has a server-side scam-analysis function, modular deterministic checks, optional AI analysis, reviewed threat intelligence, family features, and incremental database migrations. Local Flutter and backend unit checks pass after the repairs in this working tree.

Production readiness is not established. The local release build is intentionally blocked without production signing configuration; the Android emulator is offline; no Huawei crash logs, Deno runtime, Supabase CLI, or live test database are available. Consequently, this audit does not identify a proven cause for the reported HarmonyOS startup closure and does not claim that RLS or family isolation passed live integration tests.

## Architecture and feature status

| Area | Status | Evidence and remaining work |
|---|---|---|
| Flutter application | **PASS** | Flutter analysis and widget tests pass. The app uses Supabase Auth and calls server-side analysis; screen OCR uses ML Kit on Android/iOS. |
| Dependency resolution | **PASS** | Added the existing generated `flutter/pubspec.lock` to version control by unignoring only that path, pinned `material_ui` from `any` to `^1.11.0`, and ran `flutter pub get --enforce-lockfile` successfully. |
| CI for normal changes | **PASS** | GitHub Actions run [43931338872](https://github.com/XueShadow/Cyvora/actions/runs/43931338872) passed Flutter dependency validation, analysis, widget tests, backend Node tests, and Android debug build. |
| Android debug build | **PASS** | `flutter build apk --debug --no-pub` completed successfully. |
| Android release build | **BLOCKED** | `flutter build apk --release` stopped at `validateReleaseSigning` because local release signing configuration is not available. This is intentional; signing protections were not weakened. |
| Android identity and release guard | **PASS for published v1.0.1 artifacts** | Public APK/AAB checksum and signature checks passed for `com.example.cyvora_mobile`, version `1.0.1+1`, min API 24, target API 36, ARM64/ARM32/x86_64, signer SHA-256 `d732eaa269a8707b2447c73aee5a14885d030d59b9dc7382302321c750ad3afa`. This does not validate a future release. |
| Android startup diagnosis | **NOT TESTED** | Added startup phase logs and a Supabase-init failure log containing only the exception type. No Huawei logcat/crash report was available, and `emulator-5554` is offline. The exact crash cause remains unknown. |
| iOS readiness | **PARTIALLY IMPLEMENTED** | iOS bundle ID is `com.example.cyvoraMobile`, distinct from Android `com.example.cyvora_mobile`; no identity change was made. Xcode/iOS build, signing, provisioning, privacy declarations, and runtime are unverified on this Windows host. |
| Supabase Edge Functions and RLS | **PARTIALLY IMPLEMENTED** | Both configured functions use `verify_jwt = false` but manually validate bearer tokens with `auth.getUser`; they also apply the MFA challenge check before privileged operations. SQL migrations define RLS and restrict the family-invitation consumption RPC to `service_role`. No live database/RLS tests were run. |
| Family Protection | **PARTIALLY IMPLEMENTED** | Invitation codes are random, stored as hashes, expire, require the invited verified email, and are consumed under a row lock. Owner checks and family membership policies exist. The user reports the atomic quota migration was deployed, but this was not independently verified. End-to-end invitation lifecycle and cross-family tests remain missing. |
| Scam detection and trusted intelligence | **PARTIALLY IMPLEMENTED** | Deterministic modules, evidence normalization, unavailable/unknown states, moderation, redaction, reviewed examples, dataset evaluation gates, and versioned snapshots are present. A 14-case synthetic English/Filipino/Taglish evaluation fixture passed locally (7 true positives, 7 true negatives); it is only a regression fixture, not evidence of real-world accuracy. |
| AI providers | **PARTIALLY IMPLEMENTED** | Existing explicit provider selection, one primary plus at most one fallback, timeouts, structured-response validation, failure classification, and minimization remain. Local uncommitted changes add atomic global/user/per-provider request budgets and a three-failure/15-minute circuit breaker. Database migration, live behavior, and provider-side billing controls are unverified. |
| URL reputation | **PASS for mocked tests** | Adapter request/response defects and local-host filtering were corrected in the preceding commit. Tests use mocked provider responses; live provider compatibility, pricing, and quotas were not tested. |
| Laravel | **PARTIALLY IMPLEMENTED** | Laravel is a standalone scaffold; `routes/web.php` serves the default welcome page. No Flutter or Supabase integration was found. Keep it only if a separate Laravel service is intended. |

## Confirmed defects and changes

1. **Flutter lockfile was not reproducible from a clean checkout.**  
   `flutter/pubspec.lock` existed locally but `**/pubspec.lock` in `.gitignore` excluded it from Git. The release workflow already uses `flutter pub get --enforce-lockfile`, so a    clean runner could not rely on the developer's ignored file. The ignore
   exceptions now track `flutter/pubspec.lock` and the blank-only
   `supabase/.env.example` template. `material_ui: any` is now constrained to
   the currently locked compatible version range. No broad dependency upgrade
   was performed.

2. **Family invitation bodies were unbounded.**  
   `family-invitations` previously called `request.json()` without checking declared or streamed body size, and non-object JSON could reach property access and become a server error. It now uses the shared bounded-body helper with a 16 KiB cap and returns 400/413 for malformed, non-object, or oversized input. `scam-intelligence` now uses the same shared stream limiter. Focused tests cover valid objects, malformed/non-object JSON, declared oversize, and streamed oversize.

3. **Startup failure phase was difficult to distinguish from logs.**  
   Startup now emits fixed phase messages and, for Supabase initialization errors, logs only the exception type before rethrowing. It does not log the exception message, token, URL, user data, or stack. These logs aid diagnosis but cannot establish a native/OEM crash cause without device logs.

4. **Screenshot extraction error text claimed web support.**  
   The implementation rejects web and unsupported platforms; its message now correctly lists Android and iOS only.

5. **Ordinary CI coverage was missing.**  
   The separate CI workflow runs on branch pushes and pull requests to `main`.
   GitHub Actions run `43931338872` passed Flutter dependency validation,
   analysis, tests, backend tests, and Android debug build. It does not use
   release signing secrets; production release remains separate.

## Security and production risks still requiring work

- **Invitation rate-limit race:** a per-family advisory transaction lock and service-role-only RPC were added. The user reports deployment, but it was not independently verified; live concurrent-request tests remain necessary.
- **Family isolation is not live-verified:** policies and ownership checks were reviewed statically, but no two-account integration tests were run against a staging database.
- **Shared notification previews:** the Android listener persists notification title/text/package name in app-private SharedPreferences, with a queue limit. This is expected for the opt-in feature, but it is not application-layer encrypted; reassess retention and device-threat assumptions before claiming strong at-rest protection.
- **AI request guardrails require deployment:** local changes add request-count budgets and a provider circuit breaker; they are not deployed or live-tested. Request counts do not cap provider billing.
- **No live provider verification:** no provider credentials were accessed and no third-party API calls were made.
- **MFA enforcement is opt-in:** the database policy requires AAL2 for users who have a verified factor; it does not force every account to enroll MFA.
- **iOS distribution identity/signing is incomplete:** current bundle identifier is a placeholder and iOS build/signing was not checked.

## Android compatibility and crash evidence

The app's Android application ID and namespace were left unchanged. The manifest declares internet/network and notification permissions, disables backups and cleartext traffic, and declares the notification-listener service with its binding permission. The release validator records the intended API/ABI/signing constraints, but this audit did not produce a signed release artifact.

No exact HarmonyOS failure cause can be inferred from source inspection alone. To diagnose it, collect the device model, HarmonyOS build, installed APK version and SHA-256, and a redacted crash log captured at launch (for example, the crash buffer and relevant process logcat around the failure). Remove access tokens, notification content, email addresses, and other personal data before sharing logs. Do not disable Play Protect or Huawei security controls.

## Test results

| Check | Result |
|---|---|
| `flutter pub get --enforce-lockfile` | **PASS** |
| `flutter analyze --fatal-infos` | **PASS** |
| `flutter test --no-pub` | **PASS** |
| `flutter build apk --debug --no-pub` | **PASS** |
| Supabase Node tests (`node --experimental-strip-types --test supabase/tests/*.test.mjs`) | **PASS — 80 passed, 0 failed** |
| AI provider budget/circuit regression tests | **PASS — 7 focused tests (5 mocked behavior, 1 static migration contract, 1 risk-validation case); PostgreSQL behavior not executed** |
| Synthetic scam evaluation fixture | **PASS — 14 examples; 7 true positives, 7 true negatives, 0 false positives/negatives (not a real-world accuracy estimate)** |
| Atomic family invitation quota regression tests | **PASS — 2 static contract tests; database concurrency was not executable locally** |
| Android release APK build | **BLOCKED — required local production signing config is unavailable** |
| Android release validator against newly built signed APK/AAB | **BLOCKED — no signed artifacts were produced** |
| Deno Edge Function runtime tests | **NOT TESTED — Deno is not installed** |
| Live Supabase migrations, RLS, auth, and family integration tests | **NOT TESTED — Supabase CLI and a staging database are unavailable** |
| Android physical-device/Huawei test | **BLOCKED — no physical device or crash log; emulator is offline** |
| iOS build and runtime tests | **NOT TESTED — Xcode is unavailable on Windows** |
| GitHub Actions run `43931338872` | **PASS — Flutter and backend jobs passed, including Android debug build.** |

No production migrations were applied, no production secrets were read or modified, and no signing identity or application ID was changed.

## Recommended next tasks

1. Run the new CI workflow on a pull request and resolve any runner-specific failures.
2. Execute Edge Function and RLS/family tests against an isolated staging Supabase project, never production credentials.
3. Apply the new atomic invitation-quota migration and updated function to an
   isolated staging project, then run concurrent invitation-limit tests before
   requesting production rollout approval.
4. Obtain redacted Huawei crash logs and test on representative Android API levels and OEM devices.
5. Configure release signing only through the established production key and validate APK/AAB signatures, version code, and install/update behavior before any release.
6. Confirm whether Laravel is a required service; if so, document and implement its API contract separately.
7. Establish a Filipino/Taglish evaluation corpus with reviewed labels and measurable false-positive/false-negative release thresholds.
