# Cyvora Appwrite Migration Status

## Existing architecture

Cyvora is a Flutter application with Android-native notification monitoring,
Supabase Auth/PostgreSQL/Storage/Realtime/Edge Functions, and a Laravel Super
Admin application.

## Supabase inventory

- Flutter: Supabase Auth and dashboard repositories.
- Laravel: custom Supabase Auth and REST clients.
- Backend: 38 public tables, two Edge Functions, private profile avatar bucket,
  alert/family Realtime publication, and pg_cron-equivalent maintenance.
- Native Android: notification listener, filtering, consent, queue, and expiry.

## Migration progress

- IMPLEMENTED: Flutter Appwrite SDK dependency and centralized initializer,
  client provider, auth adapter, database/storage/function/realtime services,
  exception handling, and public environment configuration.
- IMPLEMENTED: 38-table logical Appwrite schema manifest and storage/function
  inventory.
- IMPLEMENTED: deployment, schema, function, security, data migration, and
  rollback documentation.
- PENDING CONFIGURATION: Appwrite database/table IDs, platforms, verification
  and recovery redirects, bucket, Function deployments, and server secrets.
- PENDING CONFIGURATION: complete server-side schema columns/indexes/permissions
  generated from source SQL and deployed to staging.
- PENDING CONFIGURATION: Flutter dashboard, realtime, storage, and privileged
  operations ported fully from Supabase adapters.
- IMPLEMENTED: Laravel official Appwrite PHP SDK dependency and server-side
  Appwrite administrator client/configuration. Existing Supabase-backed admin
  repositories remain as the active rollback implementation.
- BLOCKED: live Appwrite project provisioning and credentialed testing.
- BLOCKED: production or staging data migration and account/password migration.
- BLOCKED: server-verifiable Appwrite MFA proof for privileged operations.
