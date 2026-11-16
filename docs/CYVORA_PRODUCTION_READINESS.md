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

Production readiness is **not established**. GitHub Actions run
[43938813617](https://github.com/XueShadow/Cyvora/actions/runs/43938813617)
passed for the pushed `a6e01c8` baseline. Current follow-up changes are local
and uncommitted. Public v1.0.1 Android release
artifacts were checksum- and signature-validated against the pinned production
certificate, but this does not verify a future release. The iOS bundle ID
differs in case/spelling from Android and remains unchanged pending approval.
No exact cause for the reported HarmonyOS force-stop is known because no
device crash log was available. No Supabase migration/function deployment was
verified; no live provider call was made.

## Architecture and implementation status

| Area | Status | Evidence / remaining work |
|---|---|---|
| Flutter client and Supabase Auth | VERIFIED | Flutter analysis and widget tests previously passed locally; run the documented checks again for the current working tree before release. |
| Dependency reproducibility | VERIFIED | `flutter/pubspec.lock` is tracked, `material_ui` is constrained, and `flutter pub get --enforce-lockfile` passed locally. |
| Normal push/PR CI | VERIFIED | GitHub Actions run [43938813617](https://github.com/XueShadow/Cyvora/actions/runs/43938813617) passed Flutter dependency validation, analysis, tests, Android debug build, and backend tests for pushed commit `a6e01c8`. |
| Android identity and configuration | VERIFIED | Public v1.0.1 APK/AAB validated as `com.example.cyvora_mobile`, version `1.0.1+1`, min API 24, target API 36, ARM64/ARM32/x86_64; certificate SHA-256 `d732eaa269a8707b2447c73aee5a14885d030d59b9dc7382302321c750ad3afa` matches the repository pin. No ID or signing identity was changed. |
| Android startup and HarmonyOS | NOT TESTED | Fixed-phase startup logs exist. No Huawei crash log was supplied; the cause is unknown. The emulator was offline. |
| Android release | PARTIALLY IMPLEMENTED | The public v1.0.1 artifacts passed checksum/signature validation. A new signed release build and device install/update test were not performed. |
| iOS | PARTIALLY IMPLEMENTED | iOS bundle ID is `com.example.cyvoraMobile`, while Android is `com.example.cyvora_mobile`; this identity mismatch is not changed without approval. Xcode build/runtime, signing, provisioning, privacy declarations, and distribution remain unverified. |
| Supabase auth, RLS, and Edge Functions | PARTIALLY IMPLEMENTED | Static source/migration review and Node tests were performed. Deno, Supabase CLI, a local Supabase stack, and a staging database were unavailable; live authorization behavior is unverified. New migration `202611170003_ai_request_dedup_cooldowns.sql` remains local and uncommitted. |
| Family Protection | PARTIALLY IMPLEMENTED | Invitation tokens are hashed, expire, require verified-email matching, and are consumed under a lock. A 16 KiB request-body cap is implemented. The user reports the atomic quota migration was deployed; deployment was not independently verified, and live concurrency/family isolation tests remain unavailable. |
| Scam detection | PARTIALLY IMPLEMENTED | Deterministic message/URL rules, evidence modules, `UNKNOWN`/unavailable states, and moderation-gated indicators exist. A new 14-case synthetic fixture passed locally; it is not representative production accuracy. |
| Adaptive intelligence | PARTIALLY IMPLEMENTED | Reviewed examples, staged versioned datasets, evaluation gates, activation, and rollback support are documented/implemented. Real-world labeled data and operational evaluation are still required. |
| AI providers | PARTIALLY IMPLEMENTED | Explicit provider selection, one primary plus at most one fallback, bounded timeouts, JSON validation, global/user/provider request budgets, and a circuit breaker exist in pushed code. Local uncommitted work adds user cooldowns, HMAC request deduplication, expiring concurrency leases, stops fallback after circuit-open/HTTP 429, and skips AI when verified threat intelligence is sufficient. Deployment of the follow-up migration is unverified and PostgreSQL execution was not tested; request counts are not billing caps. Provider availability/pricing is unverified. |
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

- User-reported deployment of the atomic invitation quota fix is not
  independently verified; live concurrent-request tests remain unavailable.
- MFA is not forced for every account; AAL2 applies to users with verified
  factors.
- Family isolation and RLS need tests using separate accounts on an isolated
  database.
- AI request budgets/circuit breaker exist in pushed code, but are not
  confirmed deployed or live-tested. New cooldown/deduplication/concurrency
  controls are uncommitted and depend on a PostgreSQL migration that has only
  static contract coverage. These controls limit request counts, not provider
  spend.
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

GitHub Actions run
[43938813617](https://github.com/XueShadow/Cyvora/actions/runs/43938813617)
passed both Flutter and backend jobs for pushed commit `a6e01c8`, including
dependency validation, analysis, widget tests, backend Node tests, and the
Android debug build. Production release signing remains separate.

Checks rerun locally against the current working tree:

- `flutter analyze` — **PASSED**
- `flutter test --no-pub` — **PASSED, 59 tests**
- `node --experimental-strip-types --test supabase/tests/*.test.mjs` —
  **PASSED, 86 tests**, including provider quota/fallback/accounting,
  fingerprint, verified-threat AI-skip, and static migration-contract tests.
- Synthetic scam fixture — **PASSED, 14 examples** (included in the full Node run)

Deno Edge Function tests, PostgreSQL migration execution, live RLS/family tests,
Huawei device testing, and iOS tests remain unavailable or blocked. Flutter
analysis and widget tests passed locally. Public v1.0.1 APK/AAB signature and
checksum validation passed previously; a new release build was not produced.

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
- `supabase/migrations/202611170002_ai_provider_guardrails.sql`,
  `supabase/functions/_shared/ai-provider-analysis.ts`,
  `supabase/functions/scam-intelligence/index.ts`, and tests add fail-closed
-  daily request budgets and provider circuit-breaker logic. The uncommitted
  `202611170003_ai_request_dedup_cooldowns.sql` and related code add user
  cooldowns, HMAC-based duplicate suppression, concurrency leases, and skip
  optional AI when verified threat evidence is sufficient. No migration or
  Edge Function deployment was performed.
- `README.md`, `flutter/README.md`, and `supabase/README.md` — setup, CI,
  testing, staging-only deployment, and platform guidance.
- `supabase/TRUSTED_INTELLIGENCE.md` — corrects the documented Node type
  stripping option.
- `docs/SECURITY.md` and this report — describe evidence, safeguards, and
  verified limitations.

## Release blockers and next tasks

1. Review and commit the current local changes only after validating the SQL
    migration in an isolated PostgreSQL/Supabase environment.
2. Deploy the approved migrations and Edge Function to isolated staging,
    configure request limits and provider-side spend caps, then execute
    concurrency, RLS, and family lifecycle tests.
3. Obtain a redacted HarmonyOS crash log and test supported Android versions
   and representative OEM devices.
4. On macOS, confirm the intended iOS bundle identity before validating build,
   launch, signing, provisioning, redirect configuration, and privacy
   declarations.
5. Configure signing only through the established production identity and run
   APK/AAB signature, ABI, SDK, version, install, and update validation.
6. Use a reviewed, labeled Filipino/Taglish dataset to evaluate false
   positives and false negatives before expanding trusted rules.
7. Confirm whether Laravel is required and document its intended API boundary.

No migration or Edge Function deployment was performed during this work. The
user previously reported deploying the family invitation quota fix; that
deployment was not independently verified. No production data, credentials,
application ID, or signing identity was changed.
