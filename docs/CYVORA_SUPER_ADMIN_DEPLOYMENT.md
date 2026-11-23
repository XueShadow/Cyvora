# Cyvora Super Admin deployment guide

This is a staging-first runbook, not evidence that a deployment has occurred.
No production migration, Edge Function deployment, or Laravel release was
performed for this audit.

## 1. Prepare a staging environment

1. Create or identify a disposable Supabase project and a separate Laravel
   application/database/session store.
2. Confirm project ownership, Auth settings, recovery redirect allowlist,
   expected admin domain, and the approved Android release identity.
3. Store the Supabase service-role key only in the Laravel host's secret
   manager. Do not copy it to Vite, Blade, Flutter, CI logs, or a browser.
4. Use HTTPS, `APP_ENV=production`, `APP_DEBUG=false`, secure session cookies,
   a durable private session store, and a Laravel encryption key. Configure
   the password-reset callback as an HTTPS URL allowed by Supabase Auth.

Required Laravel environment values are listed in
[`laravel/.env.example`](../laravel/.env.example). Keep the anon/publishable
key and service-role key distinct.

## 2. Apply and verify Supabase schema in staging

1. Review every migration required by the target branch and the target
   project's migration ledger. Apply only missing migrations, in timestamp
   order, using the Supabase CLI against the isolated staging project.
2. Confirm the admin views return only the intended metadata, audit tables
   reject ordinary mutation/deletion, and service-role access remains
   server-only.
3. Run `supabase/tests/security_boundaries.test.sql` against the disposable
   local/staging database after the migrations. Confirm regular-user RLS,
   privileged MFA, family isolation, invite lifecycle, RPC grants, and
   immutable audit assertions.
4. Run `supabase/tests/notification_scan_idempotency.test.sql` and verify the
   `delete-expired-notification-scan-idempotency` `pg_cron` job was installed
   by `202611170005_notification_scan_idempotency.sql`.
5. Deploy the matching `scam-intelligence` and `family-invitations` Edge
   Function source to staging. Verify request authentication, role checks,
   MFA/AAL2 behavior, notification scan replay, moderation separation, and
   dataset release gates.
6. Record the migration ledger and deployed function revisions. A successful
   source build or local test does not prove deployment.

Do not run migration or deploy commands while the active Supabase project
could point to production. No such commands were run during this task.

## 3. Deploy Laravel to staging

From `laravel/`:

```powershell
composer install --no-dev --prefer-dist --optimize-autoloader
php artisan migrate --force
php artisan config:cache
php artisan route:list --path=admin
```

`php artisan migrate` targets the configured **Laravel** database, not the
Supabase database. Provision the Laravel encryption key once and store it in
the deployment secret manager; never replace an existing key during a routine
release because that would invalidate encrypted sessions.

Verify that production routes include the intended `/admin` surface and omit
development-only tooling. Confirm HTTPS, cookie flags, session storage,
CSRF, rate limits, no-store headers, reset callback, and service-role
configuration without printing secrets.

## 4. Provision and verify the first administrator

1. Create or identify an existing email-confirmed Supabase Auth account.
2. Through the trusted Laravel host, run:

   ```powershell
   php artisan admin:provision admin@example.com super_admin
   ```

3. Sign in through the admin domain. The first sign-in must require TOTP
   enrollment and verification; confirm that no dashboard/admin API access is
   available before AAL2.
4. Exercise each role in a staging-only test account. Verify denials as well
   as allowed routes, not only navigation visibility.
5. Confirm critical changes redirect to the fresh-MFA reauthentication flow,
   then verify the audit record has a request ID/outcome and no secrets.

## 5. Recovery, rollback, and release gates

There is no panel MFA bypass. For lost-factor recovery, an authorized project
owner must independently verify the administrator, revoke the compromised
session/factor through the trusted Supabase control plane, remove/reissue the
administrator role through the approved provisioning procedure, and require
new-factor enrollment. Record the break-glass event in an independently
protected operations log. Never issue a temporary AAL1 panel session.

Before any production release, obtain owner approval, capture a backup/restore
plan, verify staging evidence, and review the exact migration/function diff.
Do not roll back by deleting audit history or silently removing RLS/MFA
policies. Keep administrator access disabled if the database/function/app
versions are inconsistent.

Current blockers are recorded in
[production readiness](CYVORA_PRODUCTION_READINESS.md) and
[test results](CYVORA_TEST_RESULTS.md): hosted Supabase behavior is
unverified, the authorized Android signing identity must be confirmed, and
iOS/device validation requires supported hardware/tooling.
