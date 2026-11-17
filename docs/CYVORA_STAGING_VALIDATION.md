# Cyvora Staging Validation Plan

## Safety boundary

Use a new, isolated Supabase staging project or disposable local Supabase
stack, with test accounts and non-production provider credentials. Do not
point these tests at production. Do not copy production data into staging
without an approved, minimized, and scrubbed dataset. No staging project was
created or changed during this task.

The security-boundary and notification-idempotency pgTAP suites have passed
against a disposable Supabase PostgreSQL 17.11.0.018 container using direct
`psql`. This was not a full Supabase CLI stack or hosted staging project.
The base image required test-only Auth and Storage schema helpers. No staging
or production resources were created or changed.

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

The pgTAP suite does not prove true multi-session races. In staging, use two
independent authenticated requests with the same user/request ID and verify
that only one receives a lease. Also test:

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

## Edge Function and provider checks

First deploy matching migrations and Edge Function code to staging only.
Verify function versions before enabling a test provider. With provider calls
disabled, verify authentication, MFA step-up where required, bounded body
validation, quota rejection, notification replay, deleted-result behavior,
and sanitized errors.

For each provider separately, use a low-privilege staging key and a minimal
synthetic message. Verify authentication, model selection, timeout, malformed
response, 429/5xx handling, fallback stopping rules, quota accounting, and
provider-side spend alerts. Do not use real notification content. Remove
staging keys after the test. No live provider test has been performed.

## Android and Flutter device checks

On supported Android versions and at least one OEM device:

- grant and revoke notification-listener access;
- confirm the user's default SMS app is unchanged;
- queue an eligible notification, update it, and verify duplicate suppression;
- force analysis failure, confirm the preview remains available, and retry;
- kill/restart the app before and after server success and confirm no duplicate
  history rows;
- verify encrypted persistence, migration of an existing queue, 1/7/30-day
  expiration, deletion, Keystore loss behavior, reboot, and force-stop;
- inspect logs to ensure notification content, tokens, and provider inputs
  are absent; and
- disable monitoring and confirm queued content is cleared after the disclosed
  confirmation.

The current notification flow requires a user to review/select an item; it is
not automatic background analysis. Device/OEM checks remain unverified.

## Evidence to retain

Record the staging migration ledger, function revisions, pgTAP output,
multi-session test results, provider configuration status (not secret values),
device/API-level matrix, and sanitized failures. Update
`docs/CYVORA_TEST_RESULTS.md` only with checks that actually ran. Do not infer
production status from successful staging tests.
