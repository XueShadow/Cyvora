# Appwrite Functions

Create separate functions for these trust boundaries:

1. **scam-intelligence**: validate and analyze message/URL input, enforce quotas,
   preserve deduplication and provider budgets, persist results, and support
   trusted-intelligence operations.
2. **family-invitations**: create, revoke, and accept invitations atomically,
   enforce expiry and one-family membership.
3. **account-lifecycle**: perform idempotent account deletion and cleanup.
4. **admin-operations**: validate server-trusted admin roles/MFA and execute
   privileged management workflows.
5. **scheduled-maintenance**: clean expired scan history and idempotency/cache
   records.

Preserve the 10-request-per-10-minute limit and any existing 50-request daily
cloud-analysis budget implemented by the source Edge Functions.

Server secrets belong to Function environment variables. Provider credentials,
Appwrite API keys, and signing secrets must never enter Flutter builds.
