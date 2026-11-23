# Cyvora Database Validation

## Status

**BLOCKED — PostgreSQL runtime validation was not executed.**

The Supabase CLI is unavailable and the Docker daemon is not running. Docker
Desktop is also absent from this Windows host. Static SQL suites and Node tests
exist, but they do not prove migration or deployed database behavior.

## Static evidence

- 102 Supabase Node tests pass.
- `security_boundaries.test.sql` defines 17 pgTAP assertions for RLS, family
  isolation, MFA, RPC privilege, invitations, audit/cascade behavior, and AI
  quotas.
- `notification_scan_idempotency.test.sql` defines 14 pgTAP assertions for
  reservations, lease expiry/retry, replay, deletion tombstones, and duplicate
  completion.

## Not verified

- Fresh migration application.
- Migration reapplication.
- Cross-user and cross-family RLS isolation.
- Role escalation and direct RPC access.
- SECURITY DEFINER search paths and function grants.
- Storage policies.
- Notification concurrent reservations.
- pg_cron cleanup behavior.
- Deployed migration ledger and Edge Function revisions.

## Required staging commands

1. Start a disposable local Supabase project or isolated hosted Supabase
   staging project.
2. Apply every migration in filename order.
3. Run `supabase/tests/security_boundaries.test.sql`.
4. Run `supabase/tests/notification_scan_idempotency.test.sql`.
5. Reapply notification migrations and catalog-check RLS/grants/search paths.
6. Record migration IDs, pgTAP output, and all environment names.

Do not use production data or credentials for these tests.
