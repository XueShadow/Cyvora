# Appwrite Data Migration

Production data migration is not authorized and must not run automatically.

Use a sanitized staging copy and a separate staging Appwrite environment:

1. Inventory source row counts, relationships, storage hashes, timestamps, and
   effective permissions.
2. Rehearse Appwrite account migration. Supabase passwords cannot be assumed
   compatible with Appwrite; obtain a deliberate, approved account strategy.
3. Create an ID crosswalk for legacy Supabase IDs and Appwrite IDs.
4. Migrate profile/settings, family, scan, report, alert, quota, intelligence,
   audit, and account-deletion records with reconciliation.
5. Migrate private avatar objects only through an approved service credential.
6. Validate counts, ownership, permissions, file hashes, timestamps, and access
   denials.
7. Keep Supabase unchanged and available until explicit cutover approval.
