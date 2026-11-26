# Appwrite TablesDB Schema

The source-of-truth schema inventory is `appwrite/schema/database.json`. The
mapping covers all 38 public tables found in the checked-in Supabase migrations.

Appwrite resource IDs must be created in the development/staging environment and
then supplied through `APPWRITE_DATABASE_ID` and table-specific configuration.
No table or database ID is fabricated in this repository.

## Mapping rules

- Preserve source names where practical.
- Use explicit `userId`, `familyId`, `scanId`, `reportId`, and related scalar IDs.
- Server-controlled quota, lease, provider, audit, role, and deduplication rows
  are never writable by Flutter.
- Native Appwrite relationships are not assumed to reproduce Supabase cascades;
  account and family lifecycle Functions validate and reconcile those references.
- Table, row, and file permissions must be tested with anonymous, cross-user,
  cross-family, and stale-session accounts.

The source SQL remains in `supabase/migrations/`. It is a migration reference,
not a claim that deployed Supabase or Appwrite resources are identical.
