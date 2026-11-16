# Cyvora production readiness

**Assessment date:** 2026-11-17

**Repository:** `XueShadow/Cyvora`

**Production changes:** None. No production migration, secret, Supabase
setting, signing identity, or application ID was changed.

## Status definitions

- **IMPLEMENTED** — code or configuration exists.
- **VERIFIED** — the listed check actually ran and passed.
- **PARTIALLY IMPLEMENTED** — meaningful support exists, but key requirements
  or verification remain incomplete.
- **BLOCKED** — required hardware, signing material, access, or tooling was not
  available.
- **NOT TESTED** — no relevant execution or integration test was performed.
- **REQUIRES MANUAL ACTION** — an owner must configure, approve, or verify the
  item outside source code.

## Executive summary

Cyvora's existing Flutter + Supabase architecture remains intact. The
repository includes Flutter, Supabase Auth/PostgreSQL/Edge Functions, optional
AI and URL-intelligence adapters, family features, and a standalone Laravel
scaffold. Recent changes improve lockfile reproducibility, bound request
parsing, clarify startup diagnostics, and add ordinary push/PR CI.

Production readiness is **not established**. The first GitHub Actions run
failed: the backend test job could not find the locally present but ignored
`supabase/.env.example`, and the Android debug build encountered HTTP 429
responses from Maven Central while downloading Kotlin artifacts. The template
is now explicitly unignored and Gradle caching was added to CI; a follow-up
run is still required. No exact cause for the reported HarmonyOS force-stop is
known because no device crash log was available.

## Architecture and implementation status

| Area | Status | Evidence / remaining work |
|---|---|---|
| Flutter client and Supabase Auth | VERIFIED | Flutter analysis and widget tests previously passed locally; run the documented checks again for the current working tree before release. |
| Dependency reproducibility | VERIFIED | `flutter/pubspec.lock` is tracked, `material_ui` is constrained, and `flutter pub get --enforce-lockfile` passed locally. |
| Normal push/PR CI | PARTIALLY IMPLEMENTED | `.github/workflows/ci.yml` runs dependency validation, analysis, tests, backend tests, and an Android debug build. The initial run failed for a missing ignored template and a Maven Central HTTP 429. Fixes are present; follow-up GitHub execution remains pending. |
| Android identity and configuration | PARTIALLY IMPLEMENTED | Existing `applicationId`/namespace `com.example.cyvora_mobile`, version `1.0.1+1`, minimum API 24, and release validation remain unchanged. A newly signed production artifact was not produced. |
| Android startup and HarmonyOS | NOT TESTED | Fixed-phase startup logs exist. No Huawei crash log was supplied; the cause is unknown. The emulator was offline. |
| Android release | BLOCKED | Local release signing configuration was unavailable. The signing checks and established production identity were not weakened. |
| iOS | PARTIALLY IMPLEMENTED | iOS project files, plugin registration, callback scheme, and iOS 15 deployment target exist. Xcode build/runtime, signing, provisioning, privacy disclosures, and production bundle ID remain unverified. |
| Supabase auth, RLS, and Edge Functions | PARTIALLY IMPLEMENTED | Static source/migration review and Node tests were performed. Deno, Supabase CLI, a local Supabase stack, and a staging database were unavailable; live authorization behavior is unverified. |
| Family Protection | PARTIALLY IMPLEMENTED | Invitation tokens are hashed, expire, require verified-email matching, and are consumed under a lock. A 16 KiB request-body cap is implemented. A new migration and Edge Function RPC serialize the hourly quota check and insert; they are not deployed or live-concurrency tested. Full invitation lifecycle and cross-family tests remain unavailable. |
| Scam detection | PARTIALLY IMPLEMENTED | Deterministic message/URL rules, evidence modules, `UNKNOWN`/unavailable states, and moderation-gated indicators exist. A new 14-case synthetic fixture passed locally; it is not representative production accuracy. |
| Adaptive intelligence | PARTIALLY IMPLEMENTED | Reviewed examples, staged versioned datasets, evaluation gates, activation, and rollback support are documented/implemented. Real-world labeled data and operational evaluation are still required. |
| AI providers | PARTIALLY IMPLEMENTED | Explicit provider selection, required model IDs, one primary plus at most one fallback, timeouts, JSON validation, and failure categories exist. No circuit breaker or provider billing budget is implemented; live compatibility/pricing is unverified. |
| URL reputation | PARTIALLY IMPLEMENTED | Adapter behavior and local/private destination filtering have mocked coverage. No live provider calls or pricing/retention checks were performed. |
| Laravel | PARTIALLY IMPLEMENTED | Laravel currently serves a standalone scaffold/default page; no app integration contract was identified. Confirm whether it is intentionally required. |

## Security and privacy

### Confirmed safeguards

- Request bodies for `family-invitations` and centralized scam analysis are
  bounded; malformed/non-object invitation input is rejected.
- Both protected functions manually validate the bearer token and check MFA
  before privileged operations despite gateway JWT verification being
  disabled for CORS preflight support.
- Invitation consumption uses a service-role-only RPC, token hashes, expiry,
  verified-email checks, and row locking.
- AI output cannot independently promote a result to malicious over verified
  indicators. Optional external analysis requires explicit selection and
  consent.
- `supabase/.env.example` contains blank values only. Real provider keys and
  the service-role key are not included in the repository.

### Residual risks

- The deployed invitation function still has the count-then-insert race until
  the new atomic-quota migration and function are deployed. The local fix has
  static regression tests but no live concurrency test.
- MFA is not forced for every account; AAL2 applies to users with verified
  factors.
- Family isolation and RLS need tests using separate accounts on an isolated
  database.
- Provider-specific spend budgets and circuit breakers are absent.
- Android notification-listener content is kept in app-private preferences,
  but application-layer encryption and tested retention controls are absent.
- Optional third-party providers may process scan text/URLs under their own
  terms and retention policies; live policies were not checked.

See [SECURITY.md](SECURITY.md) for the safeguards and residual risks in more
detail.

## Scam evaluation

`supabase/tests/scam-evaluation.test.mjs` contains 14 synthetic labeled
examples: 7 scam-like and 7 legitimate English/Filipino/Taglish messages or
URLs. Its executed focused test reported 7 true positives, 7 true negatives,
0 false positives, and 0 false negatives (precision, recall, and accuracy
were 1.0 on this small fixture). This is only a deterministic regression
fixture; it is not a statistically meaningful estimate of real-world
accuracy. Expand the reviewed corpus before setting release thresholds.

## CI and tests

The initial GitHub Actions run was
[43926426390](https://github.com/XueShadow/Cyvora/actions/runs/43926426390):

- Backend: **FAILED** because `supabase/.env.example` was excluded from the
  clean checkout by `.gitignore`.
- Flutter dependency validation, analysis, and tests: **PASSED**.
- Android debug build: **FAILED** after Maven Central returned HTTP 429 for
  Kotlin Gradle artifacts.

This working tree adds a narrow `.gitignore` exception for the blank template
and enables Gradle caching. The corrected workflow has not yet been rerun.

Checks rerun locally against this working tree:

- `flutter pub get --enforce-lockfile` — **PASSED**
- `flutter analyze --fatal-infos` — **PASSED**
- `flutter test --no-pub` — **PASSED, 59 tests**
- `flutter build apk --debug --no-pub` — **PASSED**
- Supabase Node tests — **73 passed, 0 failed**
- Synthetic scam fixture — **PASSED, 14 examples** (included in the full Node run)

Deno Edge Function tests, live RLS/family tests, Android release-signing
validation, Huawei device testing, and iOS tests remain unavailable or blocked.

## Files changed in the current repair work

- `.gitignore` — explicitly permits only `supabase/.env.example` under the
  `.env.*` ignore rule; no secret values were found in the template.
- `.github/workflows/ci.yml` — enables Gradle dependency caching; does not use
  production signing credentials.
- `supabase/tests/scam-evaluation.test.mjs` — adds a synthetic labeled
  regression fixture.
- `supabase/migrations/202611170001_atomic_family_invite_limit.sql`,
  `supabase/functions/family-invitations/index.ts`, and
  `supabase/functions/_shared/database.types.ts` and
  `supabase/tests/family-invitation-quota.test.mjs` — implement and verify the
  atomic invitation quota path locally; production deployment was not done.
- `README.md`, `flutter/README.md`, and `supabase/README.md` — setup, CI,
  testing, staging-only deployment, and platform guidance.
- `supabase/TRUSTED_INTELLIGENCE.md` — corrects the documented Node type
  stripping option.
- `docs/SECURITY.md` and this report — describe evidence, safeguards, and
  verified limitations.

## Release blockers and next tasks

1. Rerun GitHub Actions with the tracked environment template and Gradle cache;
   investigate any remaining runner/network failure without weakening release
   signing.
2. Run the full local test suite and Flutter checks on the final tree.
3. Execute database ownership, RLS, invitation-concurrency, and family
   lifecycle tests on an isolated Supabase project with separate test users.
4. Obtain a redacted HarmonyOS crash log and test supported Android versions
   and representative OEM devices.
5. On macOS, validate iOS build, launch, signing, provisioning, redirect
   configuration, privacy declarations, and distribution identity.
6. Configure signing only through the established production identity and run
   APK/AAB signature, ABI, SDK, version, install, and update validation.
7. Use a reviewed, labeled Filipino/Taglish dataset to evaluate false
   positives and false negatives before expanding trusted rules.
8. Confirm whether Laravel is required and document its intended API boundary.

No migrations or functions were deployed. No production data, credentials,
application ID, or signing identity was changed.
