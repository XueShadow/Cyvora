# Cyvora Supabase integration

## System relationship

```text
Flutter regular-user app
  ├─ Supabase Auth session / optional user MFA
  ├─ user JWT -> PostgreSQL with RLS
  └─ user JWT -> scam-intelligence and family-invitations Edge Functions

Laravel Super Admin (server rendered)
  ├─ Supabase Auth password, MFA, refresh, and sign-out APIs
  ├─ server-only service role -> restricted admin views / Auth admin /
  │  audit and deletion workflows
  ├─ administrator user JWT -> RLS-protected dataset reads
  └─ administrator user JWT -> existing moderation/release Edge Function
```

The service-role credential never reaches a browser or Flutter client.
Supabase remains the source of truth; Laravel does not replace RLS or business
rules.

## Laravel service boundary

`SupabaseAdminClient` is the HTTP boundary. It reads URL, anon key, and
service-role key from Laravel server configuration; applies connection/request
timeouts; validates JSON and count responses; bounds page sizes; and logs
method/status without logging request or response bodies.

`SupabaseAdminRepository` maps restricted views and tables into the panel's
data models. The service role is used for the narrow admin-directory,
family/scan/report, audit, and Auth management operations. Dataset reads use
the current administrator access token so RLS remains authoritative.

Laravel validates server-assigned `app_metadata.role`, rechecks the current
Auth user and admin directory on authenticated requests, checks route
permissions, and requires MFA/AAL2. These checks are especially important for
service-role requests because the service role bypasses ordinary RLS.

## Privileged MFA contract

Roles `super_admin`, `admin`, `moderator`, and `support_admin` require a
verified Auth factor and AAL2:

1. Laravel's first-login flow enrolls a TOTP factor when none is verified.
2. The administrator verifies the factor before a panel session is stored.
3. Existing verified factors must complete a challenge at sign-in.
4. `mfa-auth.ts` rejects privileged Edge Function requests that have no
   verified factor or whose access token is not AAL2.
5. `public.mfa_access_allowed()` applies the same condition through the
   existing restrictive MFA policies. Regular accounts retain their
   existing opt-in MFA behavior.
6. Flutter blocks privileged sessions without a verified factor and supports
   TOTP and SMS challenges.

Migration `202611230003_require_mfa_for_admins.sql` updates the database
function. It must be applied and verified in an isolated Supabase environment
before the code is treated as deployed protection.

## Data and trust boundaries

- `202611230002_super_admin_panel.sql` defines restricted administration
  views, audit/deletion structures, and related reviewer policies.
- The admin panel exposes family membership and invitation metadata, but not
  family communications or invite tokens.
- Scan pages return metadata and classification, not the original message.
- Scam-intelligence moderation and dataset release call the existing Edge
  Function with a user JWT; they do not write directly through a service-role
  shortcut.
- Admin role assignments are performed by the trusted CLI/panel using Auth
  administrative operations and written only to `app_metadata`.
- AI/reputation provider secrets remain in server-side Edge Function
  configuration. Laravel shows health history and counters only.
- Audit data is append-only by the database privilege/policy design.
  PostgreSQL enforcement has not yet been verified against a deployed
  project.

## Android notification scan retries

The Android listener assigns an event-scoped UUID to each queued notification;
updates to the same system notification replace its older pending preview but
receive a distinct scan key. Flutter sends the key only for a user-approved
message scan. The Edge Function reserves `(user_id, request_id)` with an
HMAC-based content fingerprint before quota/provider work, and records the
scan plus its replay response in one database transaction. A retry after app
process loss returns the original result rather than creating another scan.
Reusing a key for different content conflicts, while deleting the scan history
leaves a bounded tombstone so an old queued item cannot recreate it.

Migration `202611170005_notification_scan_idempotency.sql` restricts the
reservation RPCs to `service_role` and schedules 35-day cleanup with `pg_cron`.
Apply and verify it in staging, then run
`supabase/tests/notification_scan_idempotency.test.sql`; neither database
operation has been performed in this worktree.

## Error behavior and verification boundary

Laravel rejects malformed/unexpected API responses and surfaces unavailable
Supabase services as an explicit error. Edge Functions validate bearer
sessions, request shape/size, role/MFA requirements, and existing domain
policies. No live credentials or provider requests were used for this audit.

Laravel HTTP tests use fakes. Supabase Node tests cover helper and mocked
function behavior. The pgTAP security-boundary and notification-idempotency
suites are prepared but not run; the Supabase CLI/PostgreSQL runtime is
unavailable. Hosted Auth behavior, RLS, SQL grants, Edge Function deployment,
and migration state remain unverified.
