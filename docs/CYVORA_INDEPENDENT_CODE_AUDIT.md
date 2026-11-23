# Cyvora Independent Code-Level Audit

> **Integration status update (2026-11-23):** This report preserves an earlier
> audit snapshot and is not current integration evidence. The integrated
> branch retains privileged MFA enforcement and includes the official Laravel
> Super Admin panel. Current local checks include 102 Supabase Node tests,
> 70 Flutter tests, Flutter analysis, 15 Android release-policy tests, and an
> Android debug build. PostgreSQL/pgTAP was not run because Docker and `psql`
> were unavailable; hosted settings and device behavior remain unverified.
> Read the
> [current complete security audit](CYVORA_COMPLETE_SECURITY_AUDIT.md),
> [remediation report](CYVORA_REMEDIATION_REPORT.md), and
> [staging plan](CYVORA_STAGING_VALIDATION.md) for current test results and
> remaining risks. The original findings below describe the earlier baseline,
> not the current branch.

**Audit date:** 2026-11-17
**Repository:** XueShadow/Cyvora
**Review type:** Independent, read-only second pass

## Executive summary

This expanded pass checked the existing audit against application, Supabase, Laravel, Android, and workflow source and ran safe local checks. It identified one **POTENTIAL HIGH-severity CI/release trust-boundary issue**: a `v*` tag can trigger release steps without a workflow-level check that its commit is an approved protected-branch commit. Whether this is exploitable depends on GitHub tag permissions, environment approvals, and secret availability, which were not inspected. No confirmed exploitable vulnerability was proven. This is not a penetration test or proof of deployed security.

The source contains several relevant controls: explicit Edge Function authentication and MFA checks, restrictive database policies and RPC grants, bounded request parsing, fixed provider endpoints, URL destination checks, and Android notification-listener binding restrictions. Their effective behavior in production remains unverified where it depends on the deployed database/functions, live providers, GitHub configuration, or device/runtime behavior.

One previously documented reliability/privacy concern was independently reconfirmed: notification items are removed from the review queue before analysis and are not restored when that analysis fails. The queue is capped by count, but no time-based expiry or application-level encryption was found in the examined storage path. This is not a newly discovered exploitable vulnerability; see [Notification handling](#6-notification-data-encryption-and-retention) and [Android background lifecycle](#9-android-background-processing-and-lifecycle).

## Classification and evidence limits

- **CONFIRMED** means the cited source behavior was observed. It does not mean production deployment or runtime behavior was verified, nor does it automatically mean a vulnerability exists.
- **POTENTIAL** means a risk depends on conditions not established in this source-only review.
- **NOT VERIFIED** means the available evidence or tools did not establish the behavior.
- **FALSE POSITIVE** means the suspected issue was not supported by the reviewed code in the stated scope.

No production systems, credentials, or database state were accessed. `supabase/.temp` was deliberately not inspected because it may contain sensitive connection metadata. The review did not execute migrations or contact AI providers.

## Security findings

**One potential release-workflow security issue requires owner verification; no exploitation was attempted.** No confirmed exploitable application vulnerability was identified.

### F-01 — Release workflow may publish an unapproved tagged ref

| Field | Assessment |
|---|---|
| Classification | POTENTIAL — source trigger/guard behavior is confirmed; exploitability depends on GitHub tag rules and environment controls |
| Severity / confidence | HIGH / 8 of 10 |
| File and lines | `.github/workflows/android-release.yml:4-16,70-81,120-147,200-203` |
| Affected component | Android release workflow tag trigger, build/signing, and publishing steps |
| Root cause | The workflow accepts matching `v*` tags and validates tag syntax, but the reviewed workflow does not verify that the tag points to an approved commit on the protected release branch. The workflow has `contents: write` permission and supplies signing secrets to release steps. Repository tag rules, environment approvals, and secret exposure controls were not inspected. |
| Safe reproduction | In a disposable repository with dummy signing values only, push a syntactically valid version tag on a commit not on the protected release branch. Observe whether release steps proceed. Do not run this against Cyvora, production credentials, or real release tags. |
| Potential impact | If an actor can create a matching tag and signing secrets are available to the job, unreviewed code may be built and published as a signed release; workflow/build changes could also put signing credentials at risk. This impact is conditional, not verified against GitHub settings. |
| Recommended remediation | Protect the release-tag namespace with a ruleset and restricted tag creation; require approval through a protected GitHub Environment before exposing signing secrets; validate the tagged commit against the approved release branch; limit `contents: write` to the publishing job/step where feasible. |
| Required regression test | In a disposable repository, verify an unapproved-ref tag is rejected before signing secrets are available and that a valid protected-branch tag requires the configured release approval. |

**Repository owner configuration required:** Create protected GitHub Environments named `android-signing` and `android-publish`, add required reviewers (and prevent self-review where supported), and allow only the default branch and stable `v*` tags. Move `ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD` to `android-signing` environment secrets and remove repository-level copies. Configure a branch ruleset requiring reviewed changes and preventing force-pushes, plus a tag ruleset restricting `v*` creation and updates to release managers. The publishing job creates a draft release; an owner must verify the draft artifacts/checksums and publish it manually. These GitHub settings were not changed or verified by this audit.

The independently reconfirmed notification queue behavior is a reliability/privacy concern rather than a demonstrated authorization or remote-exploitation vulnerability. It was already documented in the previous audit materials and is not counted as a new security finding.

## Architecture map

| Layer | Responsibility and verified connection |
|---|---|
| Flutter application | `flutter/lib/main.dart` initializes the app; `flutter/lib/auth_gate_impl.dart:8-65` gates the dashboard on the Supabase session. UI flows call `flutter/lib/dashboard/dashboard_repository.dart` for auth-backed data and analysis operations. |
| Supabase Edge Functions | `scam-intelligence` validates authenticated scan requests and composes deterministic analysis, URL reputation, and optional AI assistance. `family-invitations` handles family invitation operations. Shared code under `supabase/functions/_shared/` contains request parsing, URL/network checks, risk assessment, and provider adapters. |
| PostgreSQL / Supabase | `supabase/migrations/` defines tables, RLS policies, RPCs, quotas, and related schema changes. Client-facing data access is intended to be constrained by RLS; privileged operations use server-side functions/RPCs. Actual deployed schema and grants were not verified. |
| Android native integration | The notification-listener service queues notification previews in app-private preferences; the Flutter dashboard exposes a manual review flow. The inspected flow does not replace the default SMS application. Device lifecycle behavior was not tested. |
| Laravel | The product owner clarified on 2026-11-23 that Laravel is the intended Super Admin panel. The reviewed `laravel/routes/web.php:5-7` still serves only the default welcome page; no admin auth/RBAC or active Flutter/Supabase integration is implemented. |
| CI/CD | `.github/workflows/ci.yml` runs CI checks. `.github/workflows/android-release.yml` builds/signs/publishes release artifacts from tags or manual dispatch; see F-01 for a conditional trust-boundary concern. Hosted repository rules and secrets were not inspected. |

## End-to-end user journey

Statuses below describe source evidence, not proof that the production configuration is correct.

| Journey step | Status | Source evidence and limitations |
|---|---|---|
| Registration | CONFIRMED in source | `flutter/lib/auth_screen.dart:308-335` calls Supabase sign-up and presents a confirmation state when no session is returned. Production email-confirmation settings were not checked. |
| Email verification | CONFIRMED in source; NOT VERIFIED in production | Resend/confirmation UI appears at `flutter/lib/auth_screen.dart:347-362`; invitation consumption also requires verified email in `supabase/migrations/202606120001_dashboard_mvp.sql:284-327`. No production email delivery/configuration test was run. |
| Login | CONFIRMED in source | `flutter/lib/auth_screen.dart:308-335` handles sign-in; `flutter/lib/auth_gate_impl.dart:8-65` routes based on auth state. No live-account test was run. |
| Password recovery | CONFIRMED in source; NOT VERIFIED end-to-end | Reset request is in `flutter/lib/auth_screen.dart:389-426`; recovery event/update handling is in `flutter/lib/auth_gate_impl.dart:274-324`. Email delivery and deep-link behavior were not exercised. |
| Dashboard | CONFIRMED in source | Authenticated state routes to the dashboard/repository through `flutter/lib/auth_gate_impl.dart:50-65`. Live data and offline behavior were not exercised. |
| Manual scam analysis | CONFIRMED in source | Scan selection, disclosures, and submission are in `flutter/lib/dashboard/dashboard_screen.dart:835-920`; request validation and Edge Function invocation are in `flutter/lib/dashboard/dashboard_repository.dart:922-965`. No live backend/provider request was made. |
| URL analysis | CONFIRMED in source; NOT VERIFIED live | URL reputation/network protections are in `supabase/functions/_shared/url-reputation.ts` and `network-analysis.ts`. No live DNS/network or provider test was performed. |
| Notification monitoring | CONFIRMED in source; NOT VERIFIED on device | Android listener registration is in `flutter/android/app/src/main/AndroidManifest.xml:40-48`; queue and manual review behavior are in `MessageNotificationListenerService.kt` and `dashboard_screen.dart:320-371`. No OEM/background/permission-revocation test was run. |
| Security alerts | CONFIRMED in source; NOT VERIFIED live | Alert read operation is implemented in `flutter/lib/dashboard/dashboard_repository.dart:1601-1606`. No production notification delivery or multi-account test was run. |
| Family creation | CONFIRMED in source; NOT VERIFIED against database | Family repository operations appear in `flutter/lib/dashboard/dashboard_repository.dart:1612-1840`; live RLS authorization was not exercised. |
| Family invitations | CONFIRMED in source; concurrency NOT VERIFIED | Client operations and server-side Edge Function/RPC path are present; atomic invitation-limit SQL is in `supabase/migrations/202611170001_atomic_family_invite_limit.sql:1-72`. No concurrent PostgreSQL test was run. |
| Family member management | CONFIRMED in source; cross-account access NOT VERIFIED dynamically | Member removal/sharing operations are present in `flutter/lib/dashboard/dashboard_repository.dart:1612-1840`; database policies were reviewed statically but not executed. |
| Settings and logout | CONFIRMED in source | Settings load/update is in `flutter/lib/dashboard/dashboard_repository.dart:716-758`; logout is in `flutter/lib/dashboard/dashboard_screen.dart:1657-1663`. No live-session test was run. |

### Reconfirmed non-security reliability finding

| Field | Assessment |
|---|---|
| Classification | CONFIRMED behavior; previously documented, not a new finding in this pass |
| Severity | Low (reliability; no exploit demonstrated) |
| File and lines | `flutter/lib/dashboard/dashboard_screen.dart:320-371,973-1003` |
| Reproduction | Queue an eligible notification, start its manual analysis, then cause the analysis request to fail. The queue item has already been removed; the error is shown, but the item is not restored for retry. |
| Technical root cause | Queue removal occurs before analysis completes, and the error path does not reinsert or persist the pending item. |
| Impact | The user can lose the opportunity to analyze that notification through the queue and may need to find or enter its contents again. This audit did not establish unauthorized access or disclosure. |
| Recommended remediation | Keep the item pending until analysis succeeds or the user explicitly discards it; preserve it on failure and expose a retry path. Avoid logging notification content. |
| Test required | Add a focused widget/service test that forces analysis failure and verifies the item remains queued and can be retried; verify successful analysis removes it exactly once. |

## Coverage matrix

| # | Focus | Classification | Independent source evidence | Result and verification boundary |
|---|---|---|---|---|
| 1 | Authentication and authorization bypasses | CONFIRMED | `supabase/config.toml:3-7`; `supabase/functions/scam-intelligence/index.ts:1311-1340`; `supabase/functions/family-invitations/index.ts:47-83` | Both reviewed handlers explicitly validate the bearer token through Supabase Auth and enforce MFA despite `verify_jwt = false`. No bypass was found in the reviewed paths. No live-account or deployed-function test was performed. |
| 2 | PostgreSQL RLS and cross-account access | CONFIRMED | `supabase/migrations/202606120001_dashboard_mvp.sql:332-502` | Reviewed policies and grants constrain access around ownership and family membership. Actual cross-account isolation against a running PostgreSQL/Supabase instance was not tested. |
| 3 | Family invitation race conditions | CONFIRMED | `supabase/functions/family-invitations/index.ts:228-236,283-286`; `supabase/migrations/202611170001_atomic_family_invite_limit.sql:1-72` | Source routes invitation creation/consumption through server-side RPCs, including an atomic invitation-limit function. Concurrent execution and locking behavior were not exercised against PostgreSQL; race resistance is therefore not claimed as runtime-verified. |
| 4 | Supabase RPC permission escalation | CONFIRMED | `supabase/migrations/202606120001_dashboard_mvp.sql:502`; `supabase/migrations/202611170004_ai_request_dedup_quota_reservation.sql:1-138` | Reviewed privileged RPC grants are restricted to `service_role`; security-definer functions use a constrained search path. Actual database role grants and unauthorized-call behavior were not executed locally. |
| 5 | AI provider routing and quota enforcement | CONFIRMED | `supabase/functions/scam-intelligence/index.ts:143-160`; `supabase/functions/_shared/ai-provider-analysis.ts:322,550,726-770` | Source uses server-side reservation/completion calls, fixed provider endpoints, and rejects redirects. Runtime provider configuration, quota state, live response compatibility, and deployment revisions were not checked. |
| 6 | Notification data encryption and retention | CONFIRMED | `flutter/android/app/src/main/kotlin/com/example/cyvora_mobile/MessageNotificationListenerService.kt:10-41,56-59` | The listener stores notification title/text/package/timestamp in app-private preferences and caps the queue at 50. No time-based expiry or application-level encryption was found in this storage path. App-private storage is not by itself evidence of an exploitable vulnerability; device compromise, backup behavior, and platform encryption were not tested. |
| 7 | Scam detection correctness and false positives | CONFIRMED for the local synthetic fixture; NOT VERIFIED for real-world accuracy | `supabase/functions/scam-intelligence/scam-patterns.ts:258-280,388-405`; `supabase/tests/scam-evaluation.test.mjs:5-72,78-118` | The local fixture has 14 labeled examples and calculates evaluation metrics. The Node test run reported 7 TP, 0 FP, 7 TN, and 0 FN on that fixture. This small synthetic result does not establish production precision, recall, or false-positive rates; no representative held-out corpus or live evaluation was run. |
| 8 | URL analysis and SSRF protection | CONFIRMED | `supabase/functions/_shared/url-reputation.ts:103-127,174-198,491-535`; `supabase/functions/_shared/network-analysis.ts:125-157,281-286,314,417-435` | Source filters private/reserved destinations, checks resolved addresses before TLS probing, connects to the resolved address, and rejects redirects. Network behavior, DNS rebinding resistance, and provider interactions were not tested against a live runtime. |
| 9 | Android background processing and lifecycle | CONFIRMED for source behavior; NOT VERIFIED on device | `flutter/android/app/src/main/AndroidManifest.xml:6-10,40-48`; `flutter/android/app/src/main/kotlin/com/example/cyvora_mobile/MessageNotificationListenerService.kt:10-41,56-59`; `flutter/lib/dashboard/dashboard_screen.dart:320-371,973-1003` | The service is protected by the system notification-listener binding permission, and the UI presents queued items for manual review. The selected item is removed before analysis; the failure path displays an error but does not restore it. No device/OEM background, permission-revocation, or retry test was run. |
| 10 | API error handling and data validation | CONFIRMED for source and mocked tests; NOT VERIFIED against live providers | `supabase/functions/_shared/request-body.ts:1-76`; `supabase/functions/scam-intelligence/index.ts:1340-1351,1494-1518,1688`; `supabase/functions/_shared/ai-provider-analysis.ts:830-924`; `supabase/functions/_shared/url-reputation.ts:174-198,491-535` | The source bounds request bodies, validates inputs and structured analysis responses, bounds URL-provider response size, and rejects redirects. The 89 Node tests include mocked error/timeout/malformed-response cases. Deno and live-provider execution were unavailable, so deployed/runtime error behavior is not established. |
| 11 | Dependency and supply-chain vulnerabilities | NOT VERIFIED for known dependency advisories; CONFIRMED for workflow action pinning | `flutter/pubspec.yaml:34-41`; `laravel/composer.json:9-11`; `.github/workflows/ci.yml:11-35,41-67`; `.github/workflows/android-release.yml:15-34` | Reviewed workflow action references are SHA-pinned. No advisory database scan (`dart pub audit`, `composer audit`, or equivalent) was run, so no conclusion about known dependency CVEs is supported. |
| 12 | Build, release, and CI/CD security | CONFIRMED for reviewed repository configuration; NOT VERIFIED for current hosted execution | `.github/workflows/ci.yml:11-67`; `.github/workflows/android-release.yml:15-34` | Workflow permissions/references were reviewed and third-party actions are pinned. The current hosted workflow state, release signing environment, and production deployment configuration were not independently verified in this pass. |

### Additional stack boundaries

- **Flutter client:** The reviewed auth gate and Supabase client configuration use a publishable key, not a service-role key: `flutter/lib/auth_gate_impl.dart:14-64`; `flutter/lib/supabase_config.dart:1-12`; `flutter/lib/dashboard/dashboard_repository.dart:942-965`. No live account test was performed.
- **Prompt injection:** The reviewed provider adapter marks submitted content as untrusted and exposes no tool-execution or user-controlled provider-routing path: `supabase/functions/_shared/ai-provider-analysis.ts:171-185,587`. The suspected tool-routing risk was a **FALSE POSITIVE** in this reviewed scope. This does not guarantee model outputs are semantically safe or accurate.
- **Laravel:** The reviewed route is a standalone welcome route, not evidence of a Cyvora API boundary: `laravel/routes/web.php:5-7`. PHP was unavailable, so Laravel runtime/tests were not verified.
- **Web OCR and iOS:** The OCR bridge and local image-processing path were reviewed, but browser integration and iOS build/device behavior were **NOT VERIFIED**: `flutter/web/ocr_bridge_v2.js`; `flutter/lib/dashboard/screenshot_text_extractor_web.dart`. Xcode was unavailable.

## Complete source review

The review covered relevant application and service flows in `flutter/`, Supabase function/shared code and migrations/tests in `supabase/`, Laravel routes/configuration, Android manifest/native listener and release workflow, dependency manifests, and `.github/workflows/`. Findings below are based on source and the exact local checks listed later. This review did not execute every code path or inspect sensitive `supabase/.temp` contents; repository-wide absence of all vulnerabilities is not claimed.

## Authentication assessment

**Status: CONFIRMED source flow; production settings and live authorization NOT VERIFIED.** The client routes by Supabase auth state, provides sign-up/sign-in, confirmation resend, password reset/recovery, and logout. The reviewed Edge Functions explicitly validate bearer tokens and MFA even though function JWT verification is disabled in configuration. The client configuration uses a publishable key; no service-role key was identified in the reviewed client config. Email confirmation policy, recovery deep links, session revocation, and live account isolation were not tested.

Evidence: `flutter/lib/auth_screen.dart:308-335,347-362,389-426`; `flutter/lib/auth_gate_impl.dart:8-65,274-324`; `flutter/lib/supabase_config.dart:1-12`; `supabase/config.toml:3-7`; `supabase/functions/scam-intelligence/index.ts:1311-1342`; `supabase/functions/family-invitations/index.ts:47-83`.

## Database and RLS assessment

**Status: CONFIRMED static policy/function definitions; NOT VERIFIED on PostgreSQL or deployed project.** Migrations define ownership/family access policies, service-role RPC grants, atomic invitation limits, and AI request reservations. Static review did not substantiate a SQL injection or cross-user bypass in the examined paths. Since PostgreSQL and the Docker engine were unavailable, there is no runtime proof of RLS behavior, migration compatibility/order, lock behavior, concurrency safety, or actual production grants.

Evidence: `supabase/migrations/202606120001_dashboard_mvp.sql:284-327,332-502`; `supabase/migrations/202611170001_atomic_family_invite_limit.sql:1-72`; `supabase/migrations/202611170004_ai_request_dedup_quota_reservation.sql:1-138`.

## AI detection assessment

**Status: CONFIRMED implementation/fixture behavior; real-world accuracy and provider behavior NOT VERIFIED.** The risk assessment has branches for SAFE, SUSPICIOUS, MALICIOUS, and UNKNOWN (`supabase/functions/_shared/risk-assessment.ts:114-125`), with additional verified-threat criteria at lines 237-248. Deterministic patterns and thresholds are present. A 14-item synthetic dataset includes Filipino/Taglish examples and the local run reported 7 true positives, 7 true negatives, 0 false positives, and 0 false negatives for those examples only. This is not a representative accuracy claim.

Provider adapters constrain and parse responses and mark user-provided content untrusted; no tool execution or user-controlled provider routing was identified in the reviewed adapter. Request quotas and circuit/availability controls are request-count/runtime controls, not a monetary spending cap. No live provider authentication, model availability, billing, fallback, outage, or semantic prompt-injection behavior was tested.

Evidence: `supabase/functions/_shared/risk-assessment.ts:114-125,237-248`; `supabase/functions/scam-intelligence/scam-patterns.ts:258-280,388-405`; `supabase/tests/scam-evaluation.test.mjs:5-72,78-118`; `supabase/functions/_shared/ai-provider-analysis.ts:171-185,587,830-924`; `supabase/migrations/202611170002_ai_provider_guardrails.sql:1-120`.

## Android assessment

**Status: CONFIRMED source configuration; NOT VERIFIED on physical devices/OEM variants.** The app declares a system-protected notification listener, disables cleartext traffic and backups in the manifest, and queues notification previews in app-private preferences. The inspected flow is notification-listener based and does not require becoming the default SMS application. The preview queue is count-limited; time-based expiry and application-level encryption were not found in the reviewed path. Flutter removes the selected item before analysis and does not restore it after failure (the previously documented reliability concern).

No excessive SMS permission/default-app requirement was found in the reviewed manifest/service, but device permission UX, process death, background restrictions, data-at-rest behavior, revocation handling, and OEM compatibility were not exercised.

Evidence: `flutter/android/app/src/main/AndroidManifest.xml:6-10,40-48`; `flutter/android/app/src/main/kotlin/com/example/cyvora_mobile/MessageNotificationListenerService.kt:10-41,56-60`; `flutter/lib/dashboard/dashboard_screen.dart:320-371,973-1003`.

## Family protection assessment

**Status: CONFIRMED source flows; NOT VERIFIED with live users or concurrent database requests.** Repository operations cover family creation, invitation creation/acceptance, member management, and shared settings. Edge Function authorization checks the caller and membership/ownership before privileged work; migration policies and RPC grants were reviewed statically. Invitation quotas have a server-side atomic RPC in source. No proof of deployed migrations, live cross-family isolation, expiration behavior under concurrency, or unauthorized RPC rejection was obtained because PostgreSQL/Supabase runtime access was unavailable.

Evidence: `flutter/lib/dashboard/dashboard_repository.dart:1612-1840`; `supabase/functions/family-invitations/index.ts:47-83,228-236,283-286`; `supabase/migrations/202606120001_dashboard_mvp.sql:284-327,332-502`; `supabase/migrations/202611170001_atomic_family_invite_limit.sql:1-72`.

## Laravel assessment

**Historical scope note:** The reviewed security-branch snapshot did not
include the Laravel implementation present on `fix/mlkit-release-crash`. The
integrated branch includes the official, separate Super Admin panel; direct
Flutter-to-Laravel API integration is not required by this server-rendered
architecture. The old route inventory and test results do not describe the
integrated source. See the [Super Admin guide](CYVORA_SUPER_ADMIN_GUIDE.md)
and current test results.

Evidence: `laravel/routes/web.php:5-7`; `laravel/composer.json:9-11`.

## CI/CD assessment

**Status: CONFIRMED workflow source; GitHub rules and secrets NOT VERIFIED.** CI and Android release workflows use SHA-pinned third-party actions. The release workflow is triggered by version tags or manual dispatch, validates tag syntax, requests `contents: write`, and uses signing secrets. The workflow source itself does not establish that only approved protected-branch commits can be tagged or that a protected GitHub Environment gates secret access. This is the conditional concern in F-01, not a confirmed exploit.

Evidence: `.github/workflows/ci.yml:11-67`; `.github/workflows/android-release.yml:4-16,70-81,120-147,200-203`.

## Existing report reconciliation

No substantive code-versus-document discrepancy was verified among:

- `docs/CYVORA_PRODUCTION_READINESS.md`
- `docs/CYVORA_PRODUCTION_AUDIT.md`
- `docs/SECURITY.md`
- `supabase/PROVIDER_STATUS.md`

The documented local Flutter and Node test counts were reproduced. Production migration-ledger state and deployed Edge Function revisions were not independently checked because production access was prohibited. Their current deployment status therefore remains unverified by this pass.

## Safe local checks

| Command | Result |
|---|---|
| `node --experimental-strip-types --test supabase/tests/*.test.mjs` | PASS — 89 tests |
| `flutter analyze --fatal-infos` | PASS — no issues found |
| `Set-Location flutter; flutter test --no-pub` | PASS — 59 tests |
| `Set-Location flutter; flutter build apk --debug --no-pub` | PASS — debug APK built; Gradle emitted a restricted-Java-native-access warning |
| `git status --short` | Clean at the time checked by the reviewer |

The scam evaluation test's 7 TP / 0 FP / 7 TN / 0 FN result is only for its local synthetic fixture and must not be interpreted as a real-world performance measurement.

## Blockers and remaining verification

- PostgreSQL, PHP, and Deno were unavailable on `PATH`.
- The Docker client could not connect to its engine.
- PostgreSQL migration execution, RLS authorization tests, and concurrent invitation/quota tests were not run.
- Edge Function runtime tests, live-provider checks, and hosted deployment revisions were not verified.
- Laravel tests, Android device/OEM lifecycle behavior, and iOS build/device behavior were not verified.
- No dependency advisory scan was run.
- No production systems were modified, no migrations were deployed, and no credentials or sensitive `.temp` files were accessed.

## Remediation status

The original review above was read-only. The following separately authorized
remediation has since been applied in the current, uncommitted workspace:

| Area | Change and current verification |
|---|---|
| Android release trust boundary | Release-ref validation checks stable tags and ancestry on the default branch. Validation, signing, and publishing are separate least-privilege jobs; signing/publishing use protected GitHub Environments; publishing creates a draft. Fifteen release-ref, artifact-version, and workflow policy tests pass. GitHub branch/tag rules, reviewers, and secret placement still require owner configuration and were not inspected. |
| Notification queue reliability | Items remain queued until analysis succeeds; failures remain retryable; concurrent duplicate scans are suppressed; successful scans are durably marked in the encrypted queue before cleanup. Queue tests pass. |
| Notification privacy | Notification previews are encrypted with an Android Keystore AES/GCM key, old plaintext queue entries are migrated durably on read, retention is configurable to 1/7/30 days (default 7), expiration is scheduled, consent defaults to off, and users can delete queued previews. Consent revocation clears previews after confirmation. Successful scans are durably marked complete before queue removal. `allowBackup` is false in the Android manifest. Device/OEM and reboot/force-stop behavior remain unverified. |
| Supabase database tests | The 13-assertion security suite and 14-assertion notification suite passed via direct `psql` against disposable Supabase PostgreSQL after repository migrations were applied. This was not a hosted staging run; actual concurrent requests and deployed policy state remain unverified. |
| AI provider controls | Existing mocked provider tests and migration-contract tests passed as part of the 90-test Node suite. No credentials were read and no live provider calls or billing checks were made. Request quotas do not cap provider spend; failed provider attempts release concurrency leases but remain counted as attempted requests. |
| Dependencies/platforms | Android debug build and Flutter analysis/tests passed. No dependency advisory scan completed: `dart pub audit` is unavailable in this Dart SDK; `npm` has no lockfile here; PHP/Composer are unavailable. No device/OEM, Laravel, Deno, or iOS runtime validation was performed. |

### Current local validation

| Check | Result |
|---|---|
| Flutter analysis | PASS — no issues |
| Flutter tests | PASS — 66 tests |
| Supabase Node tests | PASS — 96 tests |
| Android release-ref, artifact-version, and workflow policy tests | PASS — 15 tests |
| Android debug build | PASS — APK built |
| PostgreSQL/pgTAP local tests | PASS — 27 assertions; hosted staging and multi-session concurrency remain unverified |
| Dependency advisory scans | NOT RUN — required audit tooling/lockfiles unavailable |
| Live providers, production, devices, Laravel, iOS | NOT TESTED |

## Updated remediation roadmap

1. Configure and verify GitHub protected branch/tag rules, environment
   reviewers, and signing secrets; test release rejection in a disposable
   repository with dummy credentials.
2. Run the new pgTAP suite and add real multi-connection invitation/quota
   concurrency tests against a disposable local or isolated staging database.
3. Verify deployed migrations and matching Edge Function revisions only in
   isolated staging, then test actual RLS/RPC behavior with separate accounts.
4. Configure provider-side spend limits and verify provider availability,
   billing behavior, and data retention in staging. Request quotas alone are
   not a monetary cap. Consider redacting personal data and OTPs before
   optional external AI processing; notification content is not yet locally
   redacted before a user-requested scan.
5. Test Android permission revocation, process death, key-loss/error handling,
   queue expiry, and deletion on representative devices. Run dependency
   advisory scans when supported tooling is available; validate Laravel and
   iOS on their supported platforms.
6. Measure classification performance on a reviewed, representative,
   held-out multilingual/Filipino dataset before making real-world accuracy
   claims.

## Production readiness conclusion

**Production readiness remains NOT VERIFIED.** The current local changes pass
the Flutter, Node, Python release-policy, and Android debug-build checks
listed above. The SQL suites pass locally, but these results do
not establish deployed migration/function alignment, runtime RLS or RPC
isolation, real concurrent quota behavior, GitHub owner settings, provider
spend/retention, Android OEM lifecycle behavior, or Laravel/iOS readiness.
No production systems were modified and no deployment was performed.

**Disposition:** The original audit is complete; remediation is local and
uncommitted. Manual owner settings and isolated staging/device validation
remain release gates.

## Laravel Super Admin follow-up — 2026-11-23

The product owner confirms Laravel is an intentional Cyvora Super Admin
component, not an optional or unused service. The route inventory contains no
admin, login, or logout routes; only the public welcome route and a
development Boost browser-log route were observed. No application RBAC model,
dashboard, Supabase client, or administrative data path exists. No
role-separated authorization test is currently possible.

`php artisan test` passes two scaffold tests only. A narrow change to
`laravel/config/session.php` makes secure cookies default on under production
while preserving the local and explicit override behavior; the three config
cases were checked with Artisan. The Boost route's production exposure remains
conditional on whether dev dependencies are installed; verify `composer
install --no-dev` and the deployed route list.
