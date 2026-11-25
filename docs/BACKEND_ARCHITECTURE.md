# Cyvora Backend Architecture

```text
Flutter View
  -> Presenter
  -> Repository contract
  -> Repository/Data Source
  -> Supabase Auth / Edge Function / PostgreSQL / Storage
```

```text
Scan:
Flutter
  -> DashboardPresenter
  -> SupabaseDashboardRepository
  -> scam-intelligence Edge Function
  -> Auth verification / MFA / quotas / RLS-backed database / AI providers
  -> typed ScanResult
  -> Presenter
  -> View
```

## Components

- **Auth:** Supabase Auth in `SupabaseAuthDataSource`.
- **Database:** PostgreSQL tables, security-definer RPCs, RLS.
- **AI:** `scam-intelligence` Edge Function and provider adapters.
- **Family:** `family-invitations` Edge Function and family tables.
- **Storage:** private `profile-avatars` bucket.
- **Android:** listener special access and encrypted local notification queue.

## Security boundaries

The Flutter client is never trusted for identity, family ownership, quotas,
moderator roles, or account deletion. Authenticated identity comes from the
Supabase access token. Privileged RPCs are restricted to `service_role`.
