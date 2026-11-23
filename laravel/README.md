# Cyvora Super Admin panel

The Laravel 13 application in this directory is Cyvora's privileged,
server-rendered Super Admin panel. Flutter remains the regular-user client;
Supabase remains the shared authentication, database, Row Level Security, and
Edge Function backend. See the [architecture map](../docs/CYVORA_ARCHITECTURE.md).

## What is implemented

- Separate `/admin` sign-in, sign-out, Supabase password recovery, and MFA
  enrollment and AAL2 sign-in for every administrator. Accounts without a
  verified factor are limited to first-time enrollment; existing verified
  TOTP or phone factors must complete a challenge.
- Four server-assigned roles: `super_admin`, `admin`, `moderator`, and
  `support_admin`. The panel trusts only Supabase `app_metadata.role`; regular
  user-editable metadata and public registration cannot grant privileges.
- Supabase role and suspension revalidation on each authenticated panel
  request, encrypted access/refresh tokens in the Laravel session, CSRF
  protection, security headers, and named request throttles.
- Authorized dashboard metrics, paginated user/family/scan/report views,
  privacy-limited family security summaries, trusted-intelligence moderation,
  provider history, global/provider usage counters, security events, and
  append-only administrative audit records.
- User suspension/reactivation and a separately reviewed account-deletion
  workflow. Destructive operations require confirmation; deletion execution
  is restricted to an independent Super Admin reviewer.
- Fresh MFA reauthentication before account, family, moderation, deletion,
  dataset-release, and administrator-role changes.

The panel intentionally does not display private message content, invitation
tokens, authentication tokens, AI secrets, per-user usage, or unredacted family
communications. Provider history and request counts are not live connectivity
checks, billing estimates, or configuration controls. Unsupported data is
shown as unavailable rather than fabricated.

## Local setup

Requirements: PHP 8.3+, Composer, and a configured Laravel database/session
store. From this directory:

```powershell
composer install
Copy-Item .env.example .env
php artisan key:generate
```

Set the following server-only values in `.env`:

```dotenv
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:8000
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVER_ONLY_SERVICE_ROLE_KEY
SUPER_ADMIN_PASSWORD_RESET_REDIRECT_URL=https://admin.example.com/admin/password/reset
```

Use the production host's secure secret store for the service-role key. Never
put it in Vite variables, Blade output, Flutter configuration, source control,
or a browser request. Production requires HTTPS for `SUPABASE_URL`; local
development may use a local Supabase HTTP URL. Set `APP_DEBUG=false`, use HTTPS,
and set `SESSION_SECURE_COOKIE=true` in production. Configure a durable,
private Laravel session/cache store; sessions contain encrypted Supabase
tokens. Add the password-reset callback to Supabase Auth's allowed redirect
URLs.

The Laravel database is used for Laravel's own framework state and sessions;
Cyvora application data remains in Supabase. Run Laravel's migrations against
the configured Laravel database:

```powershell
php artisan migrate
```

## Supabase deployment and first administrator

Review the pending SQL against the target environment, apply every required
migration in order (including `202611170005_notification_scan_idempotency.sql`,
`202611230002_super_admin_panel.sql`, and
`202611230003_require_mfa_for_admins.sql`), and deploy the current
`scam-intelligence` and `family-invitations` Edge Function revisions. Complete
this in a staging project first. Neither a successful Laravel test run nor a
local route list proves that a Supabase migration or Edge Function has been
applied to a remote project.

Create and verify the first administrator through the trusted provisioning
path. The account must already exist in Supabase Auth and have a confirmed
email:

```powershell
php artisan admin:provision admin@example.com super_admin
```

Only a trusted operator with access to the server-side service-role key should
run this command. On first sign-in, the administrator must enroll and verify a
TOTP factor before the panel creates an authenticated session. Subsequent role
assignment is available to Super Admins in the panel. Do not assign roles
through `user_metadata`, client-side settings, or Flutter.

## Role boundaries

| Role | Scope |
|---|---|
| `super_admin` | Full panel access, administrator role management, and reviewed deletion execution |
| `admin` | Operational management, moderation, analytics, audit/security review, and deletion requests |
| `moderator` | Scam-intelligence review only |
| `support_admin` | Read-only user directory |

The exact permissions are enforced server-side in
[`AdminRole`](app/Admin/AdminRole.php). Hiding a navigation item is not the
authorization boundary; each protected route checks the permission again.
Trusted-intelligence decisions still go through the existing Supabase Edge
Function and its reviewer/evaluation/release gates. Dataset reads use the
administrator's user JWT and Supabase RLS rather than the service role.

## Data and deployment limits

- A password-only session cannot access administrator routes, Edge Function
  administration, or protected RLS data. Privileged roles require a verified
  factor and AAL2; sensitive panel mutations require another MFA challenge
  within five minutes.
- MFA recovery is a trusted, out-of-band operator process, not a bypass route.
  A recovered account must be re-provisioned and enroll a new factor before
  privileged access resumes.
- Supabase SQL, RLS behavior, Auth administrative calls, and Edge Function
  operations require staging/live integration verification. They have not been
  verified against a deployed project by the repository's Laravel test suite.
- Provider status is historical only. Provider configuration/secrets must be
  managed through the backend deployment secret process; Laravel does not
  retrieve or expose them.
- No system-wide settings writer or live notification feed is exposed because
  the inspected application has no supported admin settings/event contract.
  Secret and configuration changes remain deployment-managed.
- Usage screens read the existing global and provider daily counters. They do
  not claim billing, subscriptions, per-user quotas, or user-level usage.
- Scan and family screens expose metadata and aggregates only, not private
  message bodies or alert text.
- Supabase access JWTs already issued to a user are governed by the project's
  JWT lifetime. A role change immediately blocks subsequent Laravel panel
  requests through server-side role revalidation, but deployments should use
  an appropriately short Auth JWT lifetime and revoke relevant sessions when
  demoting a compromised administrator.

## Verification

```powershell
vendor/bin/pint --test
php artisan test --compact
php artisan route:list --path=admin
```

Automated Laravel tests use HTTP fakes. The current local suite has 28 tests;
it does not replace staging verification for SQL privileges and append-only
behavior, RLS role separation, live Auth/MFA, Edge Function reviewer gates,
failure handling, or administrative audit events. See the [full security
audit](../docs/CYVORA_FULL_SECURITY_AUDIT.md) and [deployment
guide](../docs/CYVORA_SUPER_ADMIN_DEPLOYMENT.md).
