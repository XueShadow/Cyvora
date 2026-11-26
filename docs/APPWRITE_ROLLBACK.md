# Appwrite Rollback

Supabase remains operational throughout development.

Rollback criteria:

- Account flows fail in staging.
- Row or family permissions leak data.
- Privileged MFA cannot be enforced server-side.
- Quota or idempotency behavior differs under concurrency.
- Migration reconciliation fails.
- Realtime, storage, or scan-history behavior is unacceptable.

Rollback procedure:

1. Stop Appwrite cutover configuration.
2. Restore the Flutter and Laravel backend configuration to the verified
   Supabase endpoint.
3. Keep Supabase data unchanged and do not delete Supabase resources.
4. Investigate Appwrite-only writes before any rollback data reconciliation.
5. Obtain explicit approval before retrying or switching cutover.
