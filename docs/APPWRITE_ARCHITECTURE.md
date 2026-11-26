# Cyvora Appwrite Architecture Proposal

**Phase:** 1 proposal only.

**Status:** Provisional; not an approved production design or final database schema.
**Input:** [`APPWRITE_MIGRATION_AUDIT.md`](./APPWRITE_MIGRATION_AUDIT.md) and the existing Flutter/Supabase/Laravel source.

No Appwrite SDK, project, schema, Function, or application code is created by this proposal. Schema details, permission grants, role/MFA semantics, migration behavior, and plan-specific limits must be tested in an isolated Appwrite development project before implementation.

## 1. Goals and invariants

- Appwrite is the intended primary backend; do not introduce Firebase or another BaaS, and do not keep Supabase as a permanent secondary backend.
- Preserve the current Flutter user experience and MVP boundaries: views → presenters → repositories → data sources.
- Preserve Auth, registration, verification, recovery, session handling, MFA, scan analysis/history, family protection, alerts, profiles/avatars, trusted intelligence, admin operations, quotas, auditability, and Android-native notification monitoring.
- No client-side role check is an authorization boundary.
- Provider keys and Appwrite server API keys remain server-side.
- The existing Supabase project and data remain unchanged and available as the rollback source until a separately approved cutover.
- Do not perform production migration, deployment, or data deletion during the current phase.

## 2. Proposed system boundaries

```text
Flutter UI
  -> existing Presenters and repository contracts
  -> Appwrite data sources
       -> Account (ordinary user authentication)
       -> TablesDB/Storage/Realtime (only explicitly permissioned user resources)
       -> Appwrite Functions (all privileged and quota-sensitive operations)

Appwrite Functions
  -> server-side authorization, family/MFA/role checks, validation, quotas
  -> TablesDB transactions, Storage, and approved external providers

Laravel Super Admin
  -> Laravel session and CSRF protections
  -> Appwrite PHP SDK / authenticated Function APIs
  -> tightly scoped server credentials for explicitly authorized admin operations

Android notification listener
  -> remains local: consent, filtering, queue, expiry, and revocation
  -> sends only the existing eligible scan request to a server Function
```

### Flutter composition

Keep Supabase/Appwrite SDK calls out of feature views. At implementation time, replace the Supabase adapters behind the current repository contracts and inject Appwrite implementations from the app composition root. Keep typed domain models and presenter-facing outcomes independent of SDK exceptions.

Public build configuration may contain the Appwrite endpoint, project ID, database ID, table IDs, and bucket ID. These values are not secrets. Use build configuration/environment injection and validate missing/invalid values at startup. Never put an Appwrite API key, AI key, service credential, or server token in Dart source, a `--dart-define`, or browser bundle.

The official [Appwrite SDK list](https://appwrite.io/docs/sdks) includes a Flutter client SDK and PHP server SDK. Pin compatible versions only when implementation begins; the versions on the live documentation page can change.

## 3. Authentication and privileged MFA

### Ordinary account lifecycle

Use Appwrite Account for email/password signup/login, email verification, password recovery/update, sessions, logout, and account information. Keep the existing authentication UI and presenter contract. Configure the approved Web, Android, and iOS platforms and redirect URLs in the Appwrite project; handle verification, recovery, and normal login callbacks as distinct states.

Use the Appwrite SDK's documented session model and validate restored sessions against the server. Prove behavior on Android, Web, app restart, refresh/expiration, logout, and account switching before removing Supabase session handling. Do not invent a separate password or bearer-token persistence mechanism.

### Server-owned roles

The current trusted roles are `super_admin`, `admin`, `moderator`, and `support_admin`. Proposed role source: an administrator-only role/grant table or equivalent server-controlled record. Role assignment/revocation is allowed only through a tightly authorized Laravel admin operation or server Function. Never use user-editable preferences/profile fields or client-supplied role metadata.

Every privileged Function must:

1. Validate the Appwrite caller/session independently of Flutter UI state.
2. Read the trusted role from a server-controlled source.
3. Verify that the current session satisfies the privileged MFA requirement.
4. Validate the target resource and actor's authorization for that operation.
5. Fail closed on missing identity, role, factor, challenge, or assurance evidence; emit sanitized audit information.

### MFA is a release gate, not an assumption

Appwrite documents verified email/phone/TOTP factors, recovery codes, and the `user_more_factors_required` login flow in its [MFA guide](https://appwrite.io/docs/products/auth/mfa). That documents MFA capability, but does not by itself prove a Supabase AAL2-equivalent server-side gate for all privileged Function calls.

Before selecting the enforcement design, create a non-production proof of concept and test:

- A privileged account with a verified factor cannot execute privileged operations using a first-factor-only session/JWT.
- A completed MFA challenge can execute the same operation.
- A privileged account with no verified factor, disabled MFA, expired challenge, invalid/reused OTP, or recovery flow without a fresh challenge fails closed.
- A factor removal, role revocation, session refresh, account switch, and stale JWT cannot preserve privileged access.
- Regular users retain their intended experience and do not receive privileged capabilities.

If Appwrite does not expose a server-verifiable completed-MFA state for the operation, do not approximate it with client claims or an editable boolean. Design and test a server-side step-up mechanism or keep privileged functionality unavailable until a secure equivalent exists.

## 4. Data organization proposal

Use Appwrite TablesDB for structured application data. The following are logical resources; they are not final table IDs or column definitions.

### User-facing domains

- `user_profiles`, `user_settings`
- `families`, `family_memberships`, `family_invitations`
- `scan_records`, `analysis_results`, `provider_evidence`, `analysis_module_results`
- `scam_reports`, `alerts`, `alert_read_states`
- `community_threat_reports`, `detection_feedback`
- `threat_dataset_versions`, `scam_example_submissions`, `scam_example_verifications`, `scam_example_overrides`, `trusted_training_examples`

### Server-only operational domains

- Threat/reputation: `local_threat_indicators`, `threat_lookup_cache`, `provider_usage_daily`.
- Quotas: threat-analysis, URL-reputation, scam-intelligence, global AI, per-user AI, and per-provider AI usage.
- AI runtime: `ai_provider_runtime_state`, `ai_request_deduplication`, `ai_provider_attempt_leases`.
- Notification/request controls: `notification_processing_metadata`, `edge_request_windows`.
- Audit/admin: `analysis_audit_logs`, `intelligence_audit_logs`, `admin_audit_logs`, `admin_account_deletion_requests`.

Preserve the 38 source tables and their intended separation unless an approved schema design demonstrates that a consolidation preserves ownership, retention, unique constraints, audit controls, query behavior, and authorization. Keep IDs stable where Appwrite permits; otherwise retain explicit legacy IDs and a migration crosswalk. Verify custom ID constraints and collision behavior in staging.

Keep scalar ownership fields (`userId`, `familyId`, `scanId`, etc.) explicit. Evaluate native relationships only after confirming their permission/query behavior; do not assume PostgreSQL foreign keys, cascades, views, triggers, or partial indexes have direct Appwrite equivalents. Represent JSON/array evidence with bounded JSON fields or child rows only after verifying Appwrite field limits, indexes, and query semantics.

### Relationship invariants

- Profile/settings owner is the Appwrite Account user ID.
- A family has one owner; a user has no more than one active family membership.
- Invitation acceptance creates membership once and invalidates/rejects replay.
- Every scan, result, alert, report, and notification idempotency record has an explicit, immutable owner association.
- Report visibility honors the source sharing preference at query time and on Realtime delivery.
- Quota reservations, AI attempts, provider state, trusted-dataset releases, and audit events are server-controlled.
- Account deletion is idempotent and accounts for files, family relationships, operational rows, and retained audit requirements.

## 5. Authorization model

Appwrite permissions are grants. The [permissions documentation](https://appwrite.io/docs/advanced/security/permissions) explains resource-level grants and warns that server integrations with API keys can act beyond normal resource permissions. Use this model:

1. Enable row security for tables that expose rows to client sessions.
2. Do not grant broad table-level READ/UPDATE/DELETE where row-level permissions are intended.
3. Grant only the minimum table-level CREATE needed, then create rows with explicit owner/family permissions.
4. Give each row/file only the permissions required for owner, eligible family, or verified-user access.
5. Keep invitation operations, role changes, admin data, quotas, deduplication, provider controls, and audit mutation out of direct client writes.
6. Recompute/revoke family permissions when membership or sharing changes; permission revocation must be tested against existing Realtime subscriptions and cached data.
7. Test anonymous, cross-user, cross-family, stale-session, role-spoof, invalid-JWT, and unauthorized Function cases with a separate Appwrite development project.

Appwrite Teams may be evaluated as an ACL primitive for family membership, but retain an application membership record as the source of business rules until team ownership, role changes, invitation acceptance, and permission revocation have been proven to match Cyvora's one-family and family-sharing semantics. Do not make a team membership alone authorize sensitive family operations.

### Credential separation

- Flutter/browser: public Appwrite endpoint/project identifiers and user sessions only.
- Appwrite Functions: server SDK credentials and AI/reputation provider secrets in Function environment variables; use the least available key scopes.
- Laravel: server-side PHP SDK credentials in protected environment/secret storage; never serialize them into views or browser JavaScript.
- User-scoped Function paths should preserve and validate the user's session/JWT. Elevated service access is reserved for explicit server operations after actor/role/MFA checks.

## 6. Appwrite Functions

Keep all security-sensitive behavior behind Functions, organized by trust boundary. Function boundaries may be adjusted after the code-port audit; this is not a final deployment layout.

| Logical Function group | Responsibilities to preserve |
|---|---|
| Scam analysis | Validate message/URL/screenshot-extracted text; run local rules and network checks; call AI/reputation providers server-side; validate output; calculate risk/evidence; reserve and account quotas; persist scan/results atomically; return safe errors. |
| Family invitations | Create/revoke/accept invites; verify owner and target; rate-limit; enforce expiry and single use; atomically update membership and invitation state. |
| Trusted intelligence | Submit/list examples; moderator review and verification; resolve disputes; evaluate datasets; gate release to trusted admins; append audit entries. |
| Account lifecycle | Coordinate account deletion, avatar cleanup, related records and family membership with idempotent progress/retry. |
| Admin operations | Verify trusted admin role and MFA for user/role/provider/system/deletion actions; write append-only audit entries. |
| Scheduled maintenance | Expire scan history and notification-idempotency records using documented retention windows and safe retries. |

Use Appwrite database transactions for related writes where supported. The [transaction documentation](https://appwrite.io/docs/products/databases/tablesdb/transactions) describes atomic staged row operations and conflict detection; limits vary by plan. A transaction feature is not proof that the existing quota algorithms are equivalent. Test concurrent quota reservation, deduplication, cooldowns, provider leases, invite limits, and idempotent notification scans under contention. Use unique constraints/atomic operations, bounded conflict retries, and fail closed when a reservation cannot be proven.

Preserve the current AI/reputation pipeline: provider selection and enablement, bounded primary/fallback order, per-user/global/provider budgets, duplicate fingerprints, cooldowns, concurrency leases, circuit state, input/output validation, risk evidence, and sanitized provider errors. Store provider keys only in Function-side environment variables. Existing provider tests are not evidence of live connectivity; test each approved provider independently in a non-production environment.

## 7. Storage, Realtime, Messaging, and Android

### Storage

Create a private avatar bucket with explicit file permissions; preserve the current user-folder ownership, eligible family read behavior, 5 MB limit, allowed image types, replacement/deletion behavior, and account cleanup. No current evidence requires uploading screenshot bytes; retain local OCR and submit extracted text only.

### Realtime

Replace the alerts stream with an Appwrite Realtime subscription only after read/query permissions and event filtering are verified. The [Realtime guide](https://appwrite.io/docs/apis/realtime) describes permission-protected subscriptions and notes server SDKs with API keys do not access Realtime. Subscribe/unsubscribe with presenter or repository lifecycle and ensure events cannot broaden access beyond normal reads.

### Messaging

Use Appwrite Messaging only for approved backend-originated email/SMS/push needs. Do not use it as an assumed replacement for a currently unverified push-delivery system. Existing authentication verification/recovery email behavior must be configured and tested separately.

### Native notifications

Keep Android notification listener service, sensitive-content filtering, consent, notification access revocation, local queue/expiry, and platform-specific handling in Flutter/Android. Only the authenticated scan and idempotency request cross the backend boundary.

## 8. Laravel Super Admin

Keep Laravel as the Super Admin UI. Replace the custom Supabase REST/Auth client with the official Appwrite PHP SDK and explicit server-side adapters, while preserving Laravel's current admin session protections, CSRF, safe error handling, rate limits, and audit trail.

- Authenticate the admin identity and validate the current account/session server-side.
- Resolve roles from a server-only role authority, never from browser-submitted data or editable account preferences.
- Require the privileged MFA proof established by the Phase 3 POC for every sensitive action.
- Use an Appwrite server API key only in Laravel server configuration with minimal scopes; do not expose it in browser responses.
- Route sensitive workflows through Functions or narrowly scoped service methods with independent authorization and audit logging.
- Preserve account suspension/user management, family/security views, provider controls, role management, deletion requests, and append-only audit behavior.

## 9. Configuration and environments

No Appwrite project currently exists in this repository. Before implementation:

- Create an isolated development/staging project; do not connect to production Supabase for experimentation.
- Register actual Web origins, Android application ID, and iOS bundle ID as Appwrite platforms.
- Define endpoint, project ID, database/table/bucket IDs through public build/server configuration as appropriate.
- Define per-Function server secrets separately; maintain no secrets in checked-in files.
- Choose a region, Appwrite version/plan, Function runtimes, transaction limits, storage limits, and backups only after requirements and cost/availability are reviewed.
- Keep separate credentials and data for development, staging, and production. No production resource should be provisioned or changed in this phase.

## 10. Migration, verification, and rollback proposal

### Migration rehearsal

1. Inventory the deployed Supabase schema, RLS policies, grants, extensions, jobs, buckets, and data counts from an owner-approved isolated copy.
2. Build the Appwrite schema and server authorization first; verify anonymous, cross-account, cross-family, role-spoof, MFA, and function-execution denials.
3. Test Auth migration separately. Never extract plaintext passwords. Confirm user IDs, password-hash compatibility, verification status, MFA enrollment/recovery, OAuth re-authentication, and redirect flows. Force a reset/re-authentication when a secure import path is not supported.
4. Migrate a sanitized staging dataset and avatars; reconcile row counts, source IDs, owner IDs, foreign relationships, file hashes/permissions, timestamps, and retained audit records.
5. Run isolated Flutter/Laravel integration tests against Appwrite, including all current user flows and concurrent quota/invitation/idempotency operations.
6. Produce a cutover and rollback runbook. Do not dual-write indefinitely. Keep Supabase unmodified and authoritative until explicit approval; after cutover, define how new Appwrite writes would be reconciled before any rollback.

The official [migration guide](https://appwrite.io/docs/advanced/migrations/supabase) notes that PostgreSQL functions, advanced indexes, and scheduling do not migrate; OAuth users are not migrated; and Functions need a manual port. It describes source database credentials and a Supabase `service_role` key for file migration. Use only a sanctioned non-production copy/export and secure one-time handling if that migration tooling is evaluated.

### Acceptance gates

| Gate | Required evidence | Current status |
|---|---|---|
| Auth parity | Signup, email verification, login/logout, reset/update, restore/expiry, account switch, redirect/deep-link tests | NOT TESTED |
| MFA parity | Server-verifiable completed MFA for each privileged Function; fail-closed tests for AAL-equivalent cases | BLOCKED pending POC |
| Ownership/RLS parity | Isolated cross-account/cross-family and anonymous access denials | NOT TESTED |
| Role security | Server-side role assignment, spoof denial, role revocation, privileged action audit | NOT TESTED |
| Data/schema parity | Full table/relationship/index/constraint mapping and reconciliation on staging copy | BLOCKED pending isolated source snapshot |
| Functions parity | Scan, AI, reputation, family invites, trusted intelligence, deletion, quotas, idempotency | NOT TESTED |
| Storage/Realtime parity | Private avatar access, family visibility, delete cleanup, alert subscription filtering | NOT TESTED |
| Laravel parity | Admin auth, MFA, roles, management, provider state, audit and deletion workflows | NOT TESTED |
| Platform builds/tests | Flutter analyze/tests, Android debug build, Web build, Appwrite integration suites | NOT TESTED |
| Rollback readiness | Approved cutover/reconciliation/rollback runbook | NOT TESTED |

## 11. Phase 1 decisions and non-goals

- The audit and proposal are the only deliverables for this phase.
- `APPWRITE_DATABASE_SCHEMA.md`, implementation code, SDK dependency changes, migrations, Functions, Laravel changes, test infrastructure, deployments, and production data work are deferred to their respective later phases.
- No claim is made that Appwrite MFA equals Supabase AAL2, that passwords or OAuth accounts migrate, that RLS is equivalent, or that any external provider is reachable.
- Proceed to implementation only after the unresolved auth/MFA/data-migration decisions have been tested and documented in an isolated environment.
