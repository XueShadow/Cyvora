# Cyvora Independent Code-Level Audit

**Audit date:** 2026-11-17
**Repository:** XueShadow/Cyvora
**Review type:** Independent, read-only second pass

## Executive summary

This pass reviewed the four requested existing reports first, then checked claims against repository source and ran safe local tests. No confirmed exploitable vulnerability meeting the reporting threshold was identified in the reviewed source. This is not a penetration test or proof of deployed security.

The source contains several relevant controls: explicit Edge Function authentication and MFA checks, restrictive database policies and RPC grants, bounded request parsing, fixed provider endpoints, URL destination checks, and Android notification-listener binding restrictions. Their effective behavior in production remains unverified where it depends on the deployed database/functions, live providers, or device/runtime behavior.

One previously documented reliability/privacy concern was independently reconfirmed: notification items are removed from the review queue before analysis and are not restored when that analysis fails. The queue is capped by count, but no time-based expiry or application-level encryption was found in the examined storage path. This is not a newly discovered exploitable vulnerability; see [Notification handling](#6-notification-data-encryption-and-retention) and [Android background lifecycle](#9-android-background-processing-and-lifecycle).

## Classification and evidence limits

- **CONFIRMED** means the cited source behavior was observed. It does not mean production deployment or runtime behavior was verified, nor does it automatically mean a vulnerability exists.
- **POTENTIAL** means a risk depends on conditions not established in this source-only review.
- **NOT VERIFIED** means the available evidence or tools did not establish the behavior.
- **FALSE POSITIVE** means the suspected issue was not supported by the reviewed code in the stated scope.

No production systems, credentials, or database state were accessed. `supabase/.temp` was deliberately not inspected because it may contain sensitive connection metadata. The review did not execute migrations or contact AI providers.

## Security findings

**No confirmed exploitable security vulnerabilities were identified in this pass.** Accordingly, there are no vulnerability reproduction procedures or security remediations to apply from this report.

The independently reconfirmed notification queue behavior is a reliability/privacy concern rather than a demonstrated authorization or remote-exploitation vulnerability. It was already documented in the previous audit materials and is not counted as a new security finding.

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

## Recommended verification before production

1. In an isolated staging Supabase project, apply migrations through the approved deployment process and run unauthorized RPC, RLS isolation, concurrent invitation, reservation, cooldown, and expired-lease tests.
2. Deploy/verify the matching Edge Function revisions in staging and test provider authentication, timeout/rate-limit handling, malformed responses, fallback accounting, and circuit-breaker recovery without using production secrets.
3. Run supported dependency advisory scans for Flutter/Dart, Laravel/PHP, and JavaScript/TypeScript dependencies.
4. On representative Android devices, test notification permission revocation, background process death, scan failure recovery, queue retention, and user-visible data deletion behavior.
5. Evaluate scam classification on a reviewed, representative, held-out dataset and report class-specific precision, recall, F1, and false-positive rate before making accuracy claims.

**Disposition:** Audit-only report complete. No implementation or production action was taken; approval is required before major changes.
