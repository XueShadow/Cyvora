# Cyvora Final Production Checklist

## Verdict

**CONDITIONALLY READY FOR ISOLATED STAGING VALIDATION. NOT READY FOR
PRODUCTION.**

Local Flutter, backend Node, release-policy, and Android debug-build checks
passed. The new notification idempotency migration and prepared PostgreSQL
tests have not been executed. Production schema alignment, live providers,
GitHub protection rules, device behavior, and iOS readiness are unverified.

## Source and CI

- [x] Android release source validates stable tags against the default branch.
- [x] Signing and publishing use separate named GitHub Environments in source.
- [x] Release workflow uses least-privilege permissions and draft publication.
- [x] Release policy tests are run in the workflow validation job.
- [x] Flutter notification queue preserves failures and supports retry.
- [x] Notification scan request IDs support server idempotency in source.
- [x] Notification previews use encrypted local storage and consent/retention
      controls in source.
- [ ] Execute the new SQL migration and both pgTAP suites on disposable local
      Supabase and isolated staging.
- [ ] Run multi-connection race tests for notification requests, invitations,
      and AI quota reservation.

## Manual GitHub owner configuration

- [ ] Create/verify `android-signing` and `android-publish` Environments.
- [ ] Require independent reviewers and restrict deployment branches/tags.
- [ ] Store signing values only in `android-signing` Environment secrets.
- [ ] Protect the default branch and stable `v*` tags against unauthorized
      creation, updates, and force-pushes.
- [ ] Review the generated draft artifacts and checksums before publishing.

These settings were not changed or verified in GitHub during this work.

## Supabase and data

- [ ] Verify the actual target project's migration ledger and function
      revisions; repository state is not deployment evidence.
- [ ] Apply reviewed migrations `202611170001`–`202611170007` in order in
      staging, including notification idempotency and the initial-lease fix,
      and verify the required `pg_cron` cleanup job.
- [ ] Run RLS, cross-account, family isolation, unauthorized RPC, invitation
      concurrency, quota, replay, deletion, and expiry tests.
- [ ] Confirm backup/restore and retention behavior in staging.
- [ ] Keep service-role and provider secrets server-side; rotate or remove
      staging secrets after testing.

## AI, privacy, and detection

- [ ] Verify each selected provider's authentication, model, timeout, response
      handling, rate limits, failure behavior, and fallback in staging.
- [ ] Configure provider-side monetary limits; request-count quotas are not
      billing caps.
- [ ] Validate optional AI data minimization using reviewed synthetic cases;
      the current minimizer is heuristic, not complete de-identification.
- [ ] Build a representative, reviewed Filipino/Taglish and English evaluation
      corpus with held-out precision, recall, F1, and false-positive reporting.
- [ ] Verify user consent and third-party data disclosures for each provider.

## Mobile, platform, and operations

- [ ] Test Android consent, queue retry, idempotency, encryption, key loss,
      retention expiry, deletion, permission revocation, reboot, force-stop,
      and supported OEM behavior on devices.
- [ ] Confirm the default SMS application is not changed or required.
- [ ] Confirm Android/iOS application identifiers with the owner before any
      store release; no identifiers were changed.
- [ ] Build, sign, and test iOS on macOS/Xcode.
- [ ] Confirm Laravel's intended role; PHP/Composer tests did not run.
- [ ] Run supported dependency advisory scans in a prepared environment.
- [ ] Confirm incident response, logging redaction, provider spend alerting,
      and rollback procedures.

## Validation evidence

Passed locally: Flutter analyze, 66 Flutter tests, 94 Supabase Node tests,
15 Android release-policy tests, and Android debug APK build. Not run:
PostgreSQL/pgTAP, Deno runtime, PHP/Laravel, live providers, production
verification, iOS, Android device/OEM, and dependency advisory scans.
See [test results](CYVORA_TEST_RESULTS.md) and
[staging validation](CYVORA_STAGING_VALIDATION.md).
