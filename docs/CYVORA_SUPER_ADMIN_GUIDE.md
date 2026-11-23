# Cyvora Super Admin guide

Laravel is Cyvora's privileged, server-rendered administration panel.
Supabase remains the shared authentication, database, RLS, and Edge Function
backend; Flutter remains the regular-user client.

## Authentication and session controls

- Administrator identities are existing, email-confirmed Supabase Auth
  accounts. The trusted `admin:provision` command assigns a role in
  `app_metadata`; there is no public registration or client-side role editor.
- First login without a verified factor enters a TOTP enrollment flow. The
  QR code, URI, and secret are kept only in the encrypted, short-lived pending
  Laravel session and are never written to audit logs.
- After enrollment, and on later sign-ins, a verified factor and AAL2 are
  required before an admin session is stored. TOTP and verified phone factors
  are supported.
- Authenticated requests revalidate the Supabase user, role, email, and
  suspension state. Session tokens are encrypted; authentication transitions
  rotate the Laravel session ID.
- Login, MFA, password-reset, and panel access endpoints are throttled.
  Laravel's web middleware provides CSRF protection and response security
  headers; production must use HTTPS and secure cookies.
- Sensitive mutations require another MFA challenge if more than five
  minutes have elapsed since the previous successful challenge.
- There is no MFA bypass or self-service factor reset. Lost-factor recovery is
  a break-glass operator procedure outside the panel, followed by new-factor
  enrollment.

## Roles and permissions

| Role | Capabilities |
|---|---|
| `super_admin` | Dashboard, user/account management and deletion review/execution, family metadata, scans/reports, intelligence review/management/release, provider and usage views, security/audit, admin role management, settings permission. |
| `admin` | Operational user and family management, scan/report access, intelligence moderation, provider/usage views, and security/audit; cannot assign administrator roles or execute approved account deletions. |
| `moderator` | Scam-intelligence viewing and review only. |
| `support_admin` | Read-only user directory. |

The authoritative mapping is [`AdminRole`](../laravel/app/Admin/AdminRole.php).
Every protected route checks permission server-side; hiding a navigation item
is not an authorization control.

## Available modules

- **Overview:** date-filtered database-backed user, scan-risk, family, and
  report metrics, daily trends, and recent audit activity where permitted.
- **Users:** paginated directory, search/status filters, verified status,
  account suspension/reactivation, and a separately reviewed deletion
  workflow. Passwords and tokens are never shown.
- **Families:** group, authorized membership, invitation status, and
  aggregated security metadata. Private family messages are not exposed.
- **Scans and reports:** paginated scan metadata and risk labels; original
  message content is not displayed.
- **Scam intelligence:** submission review and existing Supabase dispute,
  evaluation, and release workflows. Reviewer separation and release gates
  remain enforced by the Edge Function/database.
- **Providers and usage:** stored health history and request counters. They
  are not live connectivity checks, billing estimates, or provider-secret
  management.
- **Security and audit:** security-event summaries and append-only
  administrative audit history.
- **Administrator management:** role assignment is restricted to Super Admin
  and requires reauthentication.

Subscriptions, live notifications, unsupported settings writers, per-user
billing, and provider-secret editing are not implemented. The panel reports
only data supported by current Supabase views/functions.

## Audit and privacy boundaries

Each privileged action records actor ID/role, action, target, time, outcome,
request correlation ID, and non-sensitive metadata. Never add passwords,
tokens, TOTP secrets, service-role keys, raw message text, invitation codes, or
provider credentials to audit metadata.

See [Supabase integration](CYVORA_SUPABASE_INTEGRATION.md) for which requests
use the service role versus the administrator user JWT.
