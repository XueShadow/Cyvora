# Cyvora Staging Validation Plan

## Safety boundary

Use a new, isolated Supabase staging project or disposable local Supabase
stack, with test accounts and non-production provider credentials. Do not
point these tests at production. Do not copy production data into staging
without an approved, minimized, and scrubbed dataset. No hosted staging
project or credentials were available for this validation, and no staging or
production resources were changed.

All 24 repository migrations through `202611170007` were applied in timestamp
order to a fresh disposable Supabase PostgreSQL 17.11.0.018 container using
direct `psql`. The database was bootstrapped with test-only Auth and Storage
helpers; this was not a full Supabase CLI stack or a hosted staging project.
The previously recorded 27 pgTAP assertions and 96 Supabase Node tests were
not rerun. A new, separate-connection concurrency run passed all 7 checks
listed below.

No hosted staging URL, Supabase credentials, or staging provider credentials
were available in the workspace or process environment. Therefore, migration
ledger state, deployed function revisions, hosted authorization behavior,
and live provider behavior remain unverified. No production access was
attempted.

Git state at validation start: branch
`security/complete-production-hardening`, HEAD and upstream
`392231280bbfaf1dc09096a77ebe4cbf0542e0bd`, merge base
`83fba3ccc46563c9999069f732ab3fddaa462287`. The branch has 36 committed
paths changed from `main` (+1,943/-172). One untracked patch file
(`security-hardening-review.patch`, 273,612 bytes) was preserved. Evaluation
and documentation updates from this pass are local and uncommitted.

On the disposable database, migrations `202611170005`–`202611170007` were
reapplied successfully after all 24 migrations. Catalog checks found RLS
enabled on all 31 public tables and no public `SECURITY DEFINER` functions
without a fixed `search_path`. These results are local-only.

## Before running tests

1. Confirm the staging project is isolated and has no production secrets or
   real user data.
2. Record the current staging migration ledger and deployed Edge Function
   revisions.
3. Use a disposable local Supabase stack where possible. A local reset is
   destructive to that local database; never run it against a hosted or
   production project.
4. Apply migrations using the repository's normal migration process in
   timestamp order. In particular, verify the existing pending sequence
   through `202611170007_notification_scan_reservation_initial_lease.sql`.
5. Confirm `pg_cron` is available. The new migration intentionally fails if
   automatic cleanup cannot be scheduled.
6. Configure only minimal staging test secrets. Keep provider calls disabled
   until the database-only tests pass.

## Database and authorization tests

The local SQL suites have run against a disposable database. For standard
Supabase CLI orchestration, run:

```powershell
supabase start
supabase test db
```

`supabase/tests/security_boundaries.test.sql` has 13 assertions covering
scan RLS, family access, cross-account writes, unauthorized RPC execution,
invitation expiration/reuse, deletion cascade, and AI quota behavior.

`supabase/tests/notification_scan_idempotency.test.sql` has 14 assertions
covering:

- service-role-only reservation execution and cleanup scheduling;
- initial reservation and duplicate blocking;
- request-key fingerprint mismatch;
- release and retry after a failed analysis;
- atomic scan creation and completed-result replay;
- exactly one scan record for a request key; and
- deleted-history tombstones preventing a duplicate result.

The SQL tests are not in the default Node suite; they use pgTAP. Both are
transaction-wrapped and roll back fixtures. The existing run passed all 27
assertions. It does not replace full-stack staging validation.

### Separate-connection concurrency tests

The local run used separate `psql` connections against the disposable
database, with RPC calls made as `service_role`. It passed 7/7 checks:

1. Worker A reserved a user/request key inside a transaction, held it for
   five seconds, and committed. Worker B started 0.9 seconds later on another
   connection and received `processing` after the unique-key conflict resolved;
   Worker A received `reserved`.
2. An active lease was set to expire, then retried. The retry returned
   `reserved` with a different lease token.
3. Releasing a failed scan reservation allowed the same key to be reserved
   again.
4. Completing a scan and calling completion again returned the original scan
   ID; reservation replay returned `completed`, and exactly one scan row
   existed.
5. The same request key and fingerprint for two different users produced two
   independent `reserved` results. The `authenticated` role had neither
   execute permission on the reservation RPC nor SELECT permission on the
   reservation table.
6. An actual RPC invocation under the `authenticated` role was denied.
7. An intentional division-by-zero error after reservation aborted the
   transaction. A separate connection observed no reservation row, and a
   retry successfully returned `reserved`.

These are database-level checks, not proof of deployed Edge Function
behavior. Repeat the relevant cases against isolated hosted staging using two
independently authenticated requests. Also test:

1. Same request key and same input concurrently: exactly one provider analysis
   and one scan record; the other request receives `409` or the saved replay.
2. Same request key with different input: conflict; no second scan.
3. Reservation lease expiry while a worker is stalled: only the current lease
   token may commit.
4. User deletes scan history, then the original notification is retried:
   return `410`; no new history row is created.
5. Cleanup schedule runs and removes expired idempotency rows without touching
   current rows or scan history.
6. Two family invitation requests race at the quota boundary; count never
   exceeds the configured limit.
7. Two AI requests race at global, per-user, and per-provider limits; no
   request bypasses its reservation or usage accounting.

Capture only request IDs, response status codes, test-user identifiers, and
row counts. Do not log message content or secrets.

## Hosted Supabase staging checks

When an authorized isolated staging project is available:

1. Record the hosted `supabase_migrations.schema_migrations` versions and
   deployed Edge Function revisions. Compare the ledger to the complete
   repository migration list through `202611170007`; confirm the notification
   cleanup job is scheduled.
2. Use two synthetic users in separate families to verify RLS reads/writes,
   family isolation, invite creation/acceptance authorization, and denial of
   cross-account access.
3. Verify `anon` and `authenticated` cannot execute service-role RPCs, while
   only the server-side service role can. Confirm no service-role key appears
   in Flutter assets or client requests.
4. Call protected Edge Functions without a token, with an invalid token, with
   a valid user token, and with an MFA-enabled user at each required assurance
   level. Confirm unauthorized requests do not reach providers or write data.
5. Exercise quota boundaries and simultaneous requests for notification,
   family-invite, per-user AI, and provider limits. Confirm failures are
   sanitized and do not leave stale reservations.
6. Capture only migration versions, function revisions, synthetic test-user
   IDs, status codes, and row counts. Never print tokens, message content, or
   secret values.

## Edge Function and AI provider checks

No live provider request was performed because staging provider credentials
were unavailable. For each configured provider separately, use a minimal
synthetic input and verify:

- valid and invalid requests, maximum input size, authentication, and model
  selection;
- timeout, provider outage, malformed output, HTTP 429, and HTTP 5xx behavior;
- duplicate and concurrent request handling, quota exhaustion, and
  circuit-breaker recovery; and
- that every provider failure returns an explicit failure/unavailable result
  and never a fabricated successful scam verdict.

Use provider-side staging alerts/limits where available, but do not infer
monetary caps from request quotas. Do not invent provider prices or claim a
spend limit exists without provider evidence. Remove staging keys after the
test. All live-provider cases remain unverified.

### Secret and configuration names

No values were printed, inspected, or used. The repository template names the
server-side variables below; configure only the ones required for selected
staging providers:

- Supabase Edge Functions: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
  Flutter build configuration also uses `SUPABASE_URL` and
  `SUPABASE_ANON_KEY`; the anon key is public client configuration, not a
  service-role secret.
- AI provider credentials: `GEMINI_API_KEY`, `GROQ_API_KEY`,
  `OPENROUTER_API_KEY`, `MISTRAL_API_KEY`, `CLOUDFLARE_API_TOKEN`,
  `CLOUDFLARE_ACCOUNT_ID`, `SAMBANOVA_API_KEY`, `COHERE_API_KEY`,
  `NVIDIA_API_KEY`, `ZAI_API_KEY`, `HF_TOKEN`.
- AI routing/models/limits: `AI_PROVIDER_ORDER`, `AI_FALLBACK_ENABLED`,
  `AI_GLOBAL_DAILY_REQUEST_LIMIT`, `AI_USER_DAILY_REQUEST_LIMIT`,
  `AI_<PROVIDER>_DAILY_REQUEST_LIMIT`, `AI_PROVIDER_<PROVIDER>_ENABLED`,
  and the selected provider's `*_MODEL` variable. These request limits do
  not cap currency spend.
- Optional URL reputation credentials: `URLHAUS_AUTH_KEY`,
  `GOOGLE_SAFE_BROWSING_API_KEY`, `OTX_API_KEY`, `PHISHTANK_API_KEY`,
  `URLSCAN_API_KEY`, `THREATFOX_AUTH_KEY`, `VIRUSTOTAL_API_KEY`,
  `PULSEDIVE_API_KEY`.
- Android signing workflow secrets (owner verification required):
  `ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
  `KEY_PASSWORD`.

The names come from repository code/templates only; presence and correctness
in any GitHub Environment or Supabase project were not verified.

## Android and Flutter device checks

No physical Android device was attached: `adb` was unavailable and the only
listed Android emulator (`emulator-5554`) was offline. No device or emulator
test is claimed. The release artifact validator requires `minSdk` 24 and
`targetSdk` at least 35; verify those values on the built artifact before
selecting the final device matrix.

When a physical device is available, record the manufacturer, model, Android
version/API level, security patch date, and build fingerprint. Test at least
one supported Android version and an OEM device. Cover:

- grant and revoke notification-listener access;
- confirm the user's default SMS app is unchanged;
- queue an eligible notification, update it, and verify duplicate suppression;
- force analysis failure, confirm the preview remains available, and retry;
- kill/restart the app before and after server success and confirm no duplicate
  history rows;
- test multiple notification sources and notification updates, then exercise
  Doze, App Standby, OEM battery optimization, and background-network
  restrictions; confirm retries occur only through the intended
  user-reviewed flow;
- verify encrypted persistence, migration of an existing queue, 1/7/30-day
  expiration, deletion, Keystore loss behavior, reboot, and force-stop;
- inspect logs to ensure notification content, tokens, and provider inputs
  are absent; and
- disable monitoring and confirm queued content is cleared after the disclosed
  confirmation.

The current notification flow requires a user to review/select an item; it is
not automatic background analysis. The physical-device cases above remain
unexecuted. See the separate
[physical-device test plan](CYVORA_DEVICE_TEST_PLAN.md) for test cards and
evidence fields. No per-app exclusion setting or per-notification content
length cap was found; include oversized-content and multiple-source cases and
record the intended user-visible behavior before release.

## Android release workflow and GitHub settings

The workflow source is pinned to full commit SHAs for every external action.
It validates stable `vMAJOR.MINOR.PATCH` tags and requires the target commit to
be an ancestor of the default branch; manual dispatch is restricted to that
branch. Signing and publishing use separate named Environments, job
permissions are read-only except for the publishing job, and publication is
draft-only. The build job checks APK/AAB structure, version, supported ABI and
permissions, and the expected production signing certificate before uploading
the validated artifacts.

The exact release-policy test command passed 15 tests locally on the previous
source validation. GitHub CI run [44074458843](https://github.com/XueShadow/Cyvora/actions/runs/44074458843)
passed both Flutter and backend jobs for source commit `659b79d`; it is not a
run of current HEAD or the uncommitted fixture change. No Android release
workflow run exists for this branch. GitHub Environment reviewers,
deployment branch/tag restrictions, secret placement, branch protection, and
tag rulesets require repository-owner inspection; they cannot be established
from workflow source. The workflow and artifact validator currently expect
application ID `com.example.cyvora_mobile`; the owner must confirm or replace
that identifier before a store release. See the separate
[release security review](CYVORA_RELEASE_SECURITY.md).

## Evidence to retain

Record the Git branch/commit and preserved untracked files, staging migration
ledger, function revisions, pgTAP output, multi-session test results, provider
configuration status (not secret values), device/API-level matrix, release
workflow run, manual GitHub settings review, and sanitized failures. Update
`docs/CYVORA_TEST_RESULTS.md` only with checks that actually ran. Do not infer
production status from successful staging tests.

The synthetic classifier run is documented separately in
[scam-detection evaluation](CYVORA_SCAM_DETECTION_EVALUATION.md); it is not a
substitute for a representative held-out corpus.

The user-provided Docker Scout screenshot is documented in
[Docker image analysis](CYVORA_DOCKER_IMAGE_ANALYSIS.md). Its image identity
is unverified; reproduce the scan against the exact staging/release image
digest before relying on its results.
