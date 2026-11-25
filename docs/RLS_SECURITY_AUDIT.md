# Cyvora RLS Security Audit

## Source classification

Sensitive public tables enable RLS and use authenticated ownership policies.
Quota and audit tables are revoked from public/anon/authenticated and granted
only to `service_role` where appropriate.

## Key boundaries

- Private profiles and scan records are user-scoped.
- Family members see family data only through membership predicates.
- Owners control invite creation and family settings.
- Scam reports are visible only to their author or an explicitly sharing family.
- Alert reads are scoped to a user and only visible alerts.
- Storage profile avatars use private bucket and UID-folder policies.
- Admin/reviewer tables require server-assigned app metadata roles.
- MFA access requires verified factors and AAL2 for privileged roles.

## Not tested live

Cross-account RLS, unauthorized RPC calls, hosted migration grants, storage
object policies, and policy interactions require an isolated/live PostgreSQL
environment. No production database was changed.
