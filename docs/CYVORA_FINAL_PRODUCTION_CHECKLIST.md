# Cyvora Final Production Checklist

## Verdict

**CONDITIONALLY READY FOR ISOLATED STAGING VALIDATION. NOT READY FOR
PRODUCTION.**

Local Flutter, backend Node, release-policy, Android debug-build, migration,
pgTAP, and notification-reservation concurrency checks passed. No hosted
staging project, provider credentials, or physical Android device were
available. Production schema alignment, live providers, GitHub protection
rules, device behavior, and iOS readiness remain unverified.

## Source and CI

- [x] Android release source validates stable tags against the default branch.
- [x] Signing and publishing use separate named GitHub Environments in source.
- [x] Release workflow uses least-privilege permissions and draft publication.
- [x] Release policy tests are run in the workflow validation job.
- [x] Flutter notification queue preserves failures and supports retry.
- [x] Notification scan request IDs support server idempotency in source.
- [x] Notification previews use encrypted local storage and consent/retention
      controls in source.
- [x] Applied all 24 repository migrations through `202611170007` on a fresh
      disposable Supabase PostgreSQL database; the 13 security-boundary and
      14 notification-idempotency pgTAP assertions passed.
- [ ] Apply/verify migrations and pgTAP behavior on isolated hosted staging.
- [x] Run separate-connection notification reservation checks locally: 7/7
      assertions passed for contention, expiry, retry, completion replay,
      user isolation, RPC authorization, and transaction rollback.
- [ ] Run concurrent family-invitation and AI-quota tests on isolated staging.

## Manual GitHub owner configuration

- [ ] Create/verify `android-signing` and `android-publish` Environments.
- [ ] Require independent reviewers and restrict deployment branches/tags.
- [ ] Store signing values only in `android-signing` Environment secrets.
- [ ] Protect the default branch and stable `v*` tags against unauthorized
      creation, updates, and force-pushes.
- [ ] Confirm the release application ID `com.example.cyvora_mobile` is the
      intended Play Store identity; change both Gradle and artifact validation
      configuration if it is only a placeholder.
- [ ] Review the generated draft artifacts and checksums before publishing.

These settings were not changed or verified in GitHub during this work.

## Supabase and data

- [ ] Verify the actual target project's migration ledger and deployed
      function revisions; local database state is not deployment evidence.
- [ ] Apply reviewed migrations `202611170001`–`202611170007` in order in
      staging, including notification idempotency and the initial-lease fix,
      and verify the required `pg_cron` cleanup job.
- [x] Run local RLS, cross-account, unauthorized RPC, notification replay,
      deletion, expiry, and 7-case notification concurrency checks on a
      disposable database.
- [ ] Run equivalent hosted staging checks, plus family invitation and AI
      quota concurrency tests.
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
Physical-device validation was unavailable for this gate (`adb` unavailable;
the listed emulator was offline). When available, record device/model,
Android/API level, security patch, and build fingerprint; test one supported
version and an OEM device.
- [ ] Confirm the default SMS application is not changed or required.
- [ ] Confirm Android/iOS application identifiers with the owner before any
      store release; no identifiers were changed.
- [ ] Build, sign, and test iOS on macOS/Xcode.
- [ ] Confirm Laravel's intended role; PHP/Composer tests did not run.
- [ ] Run supported dependency advisory scans in a prepared environment.
- [ ] Confirm incident response, logging redaction, provider spend alerting,
      and rollback procedures.

## Validation evidence

Passed locally: Flutter analyze, 66 Flutter tests, 96 Supabase Node tests,
15 Android release-policy tests, Android debug APK build, all 24 repository
migrations on disposable Supabase PostgreSQL, 27 pgTAP assertions, and 7
separate-connection notification-reservation checks. GitHub CI run
[44074458843](https://github.com/XueShadow/Cyvora/actions/runs/44074458843)
passed both jobs for commit `659b79decca326d5a5f77dcdcd813d5ec9afe864`.

Not verified: hosted Supabase staging, live AI providers, provider spend
controls, physical Android/OEM behavior, iOS, PHP/Laravel, and dependency
advisory scans. GitHub Environment and repository protection settings require
owner inspection. The Android release workflow has no run on this branch.
See [test results](CYVORA_TEST_RESULTS.md) and
[staging validation](CYVORA_STAGING_VALIDATION.md).
