# Cyvora Laravel Super Admin Audit

## Verified

- Composer manifest validation passes.
- Laravel PHPUnit suite passes: 28 tests, 125 assertions.
- HTTP integration tests use fake Supabase responses.
- Privileged roles require verified factors and AAL2.
- Privileged routes use named permission middleware.
- Sensitive account and intelligence mutations use reauthentication middleware.
- Sessions use encrypted Laravel session storage for pending and active admin
  payloads.
- Login and MFA routes are throttled.
- The service-role key is read only by the server-side Supabase boundary.
- Administrative access rechecks the Supabase user and restricted admin
  directory.

## Authentication and MFA

The implementation supports password sign-in, TOTP enrollment/challenge,
factor verification, pending-state expiry, reauthentication, logout, and
session fixation protection through session regeneration. Live hosted Auth
behavior remains unverified.

## Authorization

Routes are separated by dashboard, user, family, scan/report, intelligence,
provider, analytics, audit, and administrator permissions. `super_admin`,
`admin`, `moderator`, and `support_admin` are source-tested through the role
and permission maps.

## Remaining validation

- Hosted Supabase Auth issuer/audience and AAL claim behavior.
- Live session refresh, MFA factor removal, and password recovery.
- CSRF, secure-cookie, HTTPS, and security-header behavior in the deployed host.
- Dependency and framework advisory scans.
- Operational session/logout and account-lockout behavior.
