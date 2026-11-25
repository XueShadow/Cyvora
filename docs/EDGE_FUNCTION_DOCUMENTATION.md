# Cyvora Edge Function Documentation

## `scam-intelligence`

- Auth: bearer access token; gateway JWT verification enabled.
- Manual validation: `auth.getUser`, MFA/session checks.
- Body limit: 64 KiB.
- Scans: 30 daily scan RPC plus 10 cloud requests per 10 minutes for AI use.
- Cloud AI: bounded provider daily budgets default to 50.
- Notification: reservation, replay, conflict, deletion, and completion RPC.
- Account deletion: explicit confirmation phrase and `auth.admin.deleteUser`.
- Storage: profile avatar objects are removed before account deletion.

## `family-invitations`

- Auth: bearer access token; gateway JWT verification enabled.
- Manual validation: session and MFA checks.
- Body limit: 16 KiB.
- Owner/revoke/accept actions use server-side ownership checks.
- Invitation tokens are stored only as SHA-256 hashes.

## Security

Both functions use service-role clients server-side, fixed CORS headers,
validated JSON, HTTP status distinctions, and no-store AI responses.
