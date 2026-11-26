# Cyvora Appwrite Migration Audit — Phase 1

**Status:** Source inventory complete; this is not a migration or a live-backend security attestation.

**Scope:** Read-only inspection of the Flutter app, Supabase migrations and Edge Functions, Laravel Super Admin, Android notification monitoring, tests, and current backend documentation.
**Repository baseline:** `66c27f5` (`Harden authentication error and MFA handling`) plus pre-existing uncommitted work. Only this new audit and its companion architecture proposal are being added for this task.

## Executive summary

Cyvora is currently a Flutter application backed by Supabase Auth, PostgreSQL, Storage, Realtime, and two authenticated Edge Functions. A Laravel application provides a separate Super Admin interface using custom Supabase REST/Auth calls. Android notification monitoring and filtering are native/local and must remain so.

The Supabase-to-Appwrite mapping below is based on the checked-in source and **27 SQL migration files**. No Appwrite SDK or project configuration is present. No database or hosted backend was contacted. The checked-in migrations are not proof of the deployed schema, effective grants, RLS behavior, data volume, or production settings.

| Area | Status | Evidence / limitation |
|---|---|---|
| Flutter backend call-site inventory | PASS | Supabase initialization, authentication, and dashboard data access are centralized in the application/data layers; the dashboard repository is the main backend boundary. |
| Supabase schema and migration inventory | PASS | 27 checked-in migrations define 38 public tables, views, RLS policies, RPCs, triggers, and retention jobs. Static source only. |
| Effective deployed schema, grants, and RLS | BLOCKED | No live or isolated PostgreSQL catalog was queried. Migration SQL alone cannot verify deployed state or effective permissions. |
| Supabase Edge Function inventory | PASS | `scam-intelligence` and `family-invitations` are present; both have `verify_jwt = true` in `supabase/config.toml`. |
| Storage and Realtime inventory | PASS | One private avatar bucket is defined; the alerts stream and publication membership are identified from source. |
| Laravel Super Admin integration | PASS | Custom server-side Supabase Auth/REST client, trusted-role checks, MFA flow, admin views, user management, and audit operations are mapped. |
| Android notification-monitoring boundary | PASS | Listener, filtering, queue storage, and expiry are Android-native; this migration must not relocate them to a BaaS. |
| Appwrite SDK, project, schema, and platform setup | NOT TESTED | No Appwrite package, project, IDs, or credentials were found; no project was created or contacted. |
| Account/password migration behavior | BLOCKED | No isolated migration rehearsal was run. Appwrite's migration guide documents OAuth limitations but does not establish that Supabase password hashes or all verification/MFA state can be imported. |
| Provider connectivity and live Appwrite authorization | NOT TESTED | No external provider or Appwrite requests were made. Existing unit/source tests are not live service verification. |

## 1. Existing backend topology

### Flutter

- Flutter depends on `supabase_flutter` (currently `^2.18.3`); no Appwrite dependency or Appwrite references were found.
- `lib/app/app_initializer.dart` initializes Supabase and `lib/app/app_dependencies.dart` injects the data/repository dependencies.
- Authentication operations are routed through `SupabaseAuthDataSource` and `SupabaseAuthenticationRepository`; the authentication presenter and views consume that contract.
- `lib/data/repositories/dashboard_repository.dart` is the primary Supabase data boundary for settings, scans/history, alerts, families/reports, avatars, trusted-intelligence reads, account deletion, and Edge Function calls.
- Supabase operations are not spread through the feature widgets in the searched source. Keep the existing presenter/repository separation when introducing Appwrite.

### Supabase services

| Supabase component | Current use | Appwrite component to evaluate |
|---|---|---|
| Auth | Email/password registration and login, verification, resend, recovery/password update, session restoration/logout, account switching, MFA factors/challenges and assurance handling | Appwrite Account; verification/recovery deep links; MFA challenge/session behavior must pass a server-side privileged-access proof of concept |
| PostgreSQL / PostgREST | User, family, scan, alert, report, settings, intelligence, quota, and admin data | Appwrite TablesDB, row security, explicit row permissions, indexes, and Functions |
| RLS and RPC | Ownership/family visibility, MFA gates, trusted-role policies, atomic quotas, invitations, scan persistence and idempotency | TablesDB table/row permissions plus Functions that independently validate caller identity, family membership, trusted roles, MFA, rate limits, and business rules |
| Storage | Private `profile-avatars` bucket, user-scoped object paths and family read access | Appwrite Storage bucket with explicit per-file permissions, allowed MIME types, and size limit |
| Realtime | Alerts stream; `alerts` and `family_members` are added to the Realtime publication in migrations | Appwrite Realtime channels, gated by the same row/file permissions as reads |
| Edge Functions | Scam/URL analysis, AI and reputation provider calls, trusted-intelligence operations, account deletion, and family invites | Appwrite Functions; provider secrets remain function-side |
| `pg_cron` | Daily scan-history cleanup and notification-idempotency cleanup | Scheduled Appwrite Function(s), with retry, observability, and idempotent cleanup |

## 2. Flutter feature and flow inventory

| Flow / feature | Current backend behavior | Migration requirement |
|---|---|---|
| Registration and identity | Supabase Auth creates the account; the app submits signup metadata and handles confirmation state. Profile/settings initialization is backed by Auth/PostgreSQL triggers. | Appwrite Account must preserve the existing form and verification lifecycle. Create profile/settings idempotently; do not accept client-supplied role fields as authorization. |
| Verification and recovery | Supabase redirect/deep-link flow handles verification, recovery, password update, and login callbacks. | Configure Web and mobile Appwrite platforms and redirect URLs. Distinguish verification, recovery, and normal sign-in callbacks. Test expired/reused/malformed links. |
| Login, logout, session | Supabase SDK manages sessions; the auth gate restores and validates session/MFA state. | Verify native/Web persistence and expiration using the official SDK. Do not add a custom plaintext password/token store. Verify account switching and stale-session denial. |
| MFA and privileged access | Flutter presents factors/challenges; trusted role enforcement is also implemented in Supabase migrations/Edge Functions and Laravel. | Appwrite MFA UI support is not sufficient by itself. A Function must prove a privileged call has a completed MFA session and a server-trusted role before granting access. See the unresolved MFA gate below. |
| Settings and privacy | Reads/updates `user_settings`; includes scan-history retention and sharing/notification preferences. | Keep user-owned settings private. Do not treat client-selected retention or sharing preferences as authorization for other users' data. |
| Scam scan and history | Reads/writes scan records and analysis evidence; scan execution is delegated to the `scam-intelligence` Function. Screenshot OCR is local; extracted text, not image bytes, is submitted for analysis. | Preserve scan input types and response contract; persist evidence and enforce quota/deduplication server-side. Do not upload screenshots unless a separately approved feature requires it. |
| AI assistant and URL reputation | AI assistant and reputation checks are server-side Function operations. | Keep all provider credentials in Appwrite Function environment variables. Preserve provider order/fallback, content validation, budgets, cooldowns, concurrency limits, duplicate detection, and safe errors. |
| Family protection | Reads family, membership, profile, invitation, and report data; direct data access coexists with `family-invitations` Function operations. | Keep membership and invitation lifecycle server-authorized. Preserve the one-family membership rule, owner/member roles, verified-email requirements, expiry, revocation, and single-use acceptance. |
| Alerts | Streams `alerts`, reads `alert_reads`, and records read state. | Use private row permissions and Appwrite Realtime. A subscription must never reveal events the caller could not read through a normal query. |
| Profile/avatar | Reads profile data and uploads/deletes objects from the private avatar bucket. | Preserve user-only mutation, family-scoped read access, file validation, and cleanup during account deletion. |
| Trusted intelligence | Reads `dataset_versions`; submits examples, reads own submissions, and performs reviewer/admin actions through the `scam-intelligence` Function. | Keep review, evaluation, dispute resolution, and dataset release server-side; only authorized moderators/admins may mutate this state. |
| Account deletion | Delegates deletion to the `scam-intelligence` Function, which coordinates avatar and backend cleanup. | Implement an idempotent deletion workflow covering Auth, files, all user-owned rows, family membership, and audit requirements. Do not assume database foreign-key cascades exist in Appwrite. |

## 3. Supabase table inventory and proposed Appwrite mapping

The right column names are **logical target resources**, not finalized Appwrite IDs or a finalized schema. Keep sensitive operational records inaccessible to Flutter clients. Existing UUIDs and relationships need an isolated migration rehearsal before deciding whether to reuse IDs or maintain an ID crosswalk.

| Supabase table | Current purpose / access boundary | Proposed Appwrite resource |
|---|---|---|
| `profiles` | User profile; self-managed, with limited family visibility | `user_profiles` |
| `user_settings` | Per-user privacy, retention, sharing, and notification settings | `user_settings` |
| `families` | Family record; members read, owner manages | `families` |
| `family_members` | Membership and family role; family-scoped access | `family_memberships` |
| `family_invites` | Invitation state; owner and invite lifecycle | `family_invitations`, with create/revoke/accept through a Function |
| `scan_records` | Private user scan history | `scan_records` |
| `threat_scan_results` | Scan verdict/evidence, private to the scan owner | `analysis_results` |
| `threat_provider_results` | Provider evidence associated with an owner's scan | `provider_evidence` |
| `analysis_module_results` | Persisted analysis-module evidence, private to owner | `analysis_module_results` |
| `scam_reports` | User reports; author/family visibility depends on sharing policy | `scam_reports` |
| `alerts` | User/family-visible alerts and scan/report notifications | `alerts` |
| `alert_reads` | Per-user read state for visible alerts | `alert_read_states` |
| `threat_analysis_usage` | Server-enforced threat-analysis quota | `quota_threat_analysis_daily` |
| `url_reputation_usage` | Server-enforced reputation quota | `quota_url_reputation_daily` |
| `scam_intelligence_usage` | Server-enforced scan/analysis quota | `quota_scam_intelligence_daily` |
| `threat_lookup_cache` | Internal reputation lookup cache | `threat_lookup_cache` |
| `threat_provider_daily_usage` | Provider budget accounting | `provider_usage_daily` |
| `scam_patterns` | Server-side classification patterns | `scam_patterns` |
| `detection_feedback` | User feedback associated with detection | `detection_feedback` |
| `analysis_audit_logs` | Internal analysis audit/event record | `analysis_audit_logs` |
| `local_threat_indicators` | Internal indicator/hash records | `local_threat_indicators` |
| `community_threat_reports` | Submitted/reviewed threat indicators | `community_threat_reports` |
| `example_submissions` | User-submitted training examples and review state | `scam_example_submissions` |
| `example_verifications` | Reviewer verification of examples | `scam_example_verifications` |
| `example_admin_overrides` | Restricted administrative overrides | `scam_example_overrides` |
| `dataset_versions` | Trusted dataset release/version metadata | `threat_dataset_versions` |
| `trusted_training_examples` | Approved training examples | `trusted_training_examples` |
| `intelligence_audit_logs` | Trusted-intelligence audit trail | `intelligence_audit_logs` |
| `ai_global_daily_usage` | Global AI provider budget | `ai_usage_global_daily` |
| `ai_user_daily_usage` | Per-user AI usage budget | `ai_usage_user_daily` |
| `ai_provider_daily_usage` | Per-provider daily usage budget | `ai_usage_provider_daily` |
| `ai_provider_runtime_state` | Provider availability/circuit state | `ai_provider_runtime_state` |
| `ai_request_deduplication` | User/request duplicate detection | `ai_request_deduplication` |
| `ai_provider_attempt_leases` | Provider reservation, cooldown, and concurrency lease | `ai_provider_attempt_leases` |
| `notification_scan_idempotency` | Notification-originated scan reservation/result state | `notification_processing_metadata` |
| `edge_request_windows` | Server-side request-window/rate-limit state | `edge_request_windows` |
| `admin_audit_logs` | Append-only Super Admin audit log | `admin_audit_logs` |
| `admin_account_deletion_requests` | Restricted account-deletion review workflow | `admin_account_deletion_requests` |

**Count:** 38 public tables found in checked-in migrations. This count excludes Supabase-managed `auth`, `storage`, and internal schemas.

### Relationships and invariants to preserve

The checked-in migrations define these foreign-key relationships and deletion semantics:

- **Auth ownership:** `profiles`, `user_settings`, `scan_records`, `scam_reports`, `alerts.user_id`, `alert_reads`, `threat_analysis_usage`, `url_reputation_usage`, `scam_intelligence_usage`, `threat_scan_results`, `threat_provider_results`, `threat_provider_daily_usage`, `detection_feedback`, `analysis_audit_logs`, `analysis_module_results`, `community_threat_reports.reporter_id`, `example_submissions.reporter_id`, AI user usage/deduplication/attempt leases, `notification_scan_idempotency`, and `edge_request_windows` reference `auth.users`. Most cascade on account deletion; reviewer/actor fields that preserve provenance use `SET NULL` or `RESTRICT` where specified.
- **Family graph:** `families.owner_id` references an Auth user and is unique; `family_members.family_id` and `family_invites.family_id` cascade from `families`; `family_members.user_id` references a unique Auth user. `family_invites.invited_by` cascades from Auth. `scam_reports.family_id` is set null when a family is removed, while `alerts.family_id` cascades.
- **Reports, scans, and alerts:** `alerts.scan_record_id` and `alerts.report_id` cascade from their source records; `alert_reads.alert_id` cascades from `alerts`. `threat_scan_results.scan_record_id` is unique and cascades from `scan_records`; `threat_provider_results` has a composite `(threat_scan_result_id, user_id)` reference to `(threat_scan_results.id, user_id)` and is unique per scan/provider/indicator. `analysis_module_results.threat_scan_result_id` cascades from the result. `detection_feedback.scan_record_id` cascades; `analysis_audit_logs.scan_record_id` is set null.
- **Threat review:** `local_threat_indicators.reviewed_by` and `community_threat_reports.reviewed_by` reference Auth users with `SET NULL`; community reporters cascade on user deletion.
- **Trusted intelligence:** submissions reference Auth reporters with cascade and optional scan records with `SET NULL`; verifications reference submissions with cascade and reviewers with `RESTRICT`; admin overrides reference submissions with cascade and admins with `RESTRICT`. Dataset creator/approver references use `SET NULL`. Training examples reference an optional unique submission with `SET NULL` and a dataset version with `RESTRICT`. Intelligence audit actors, submissions, and dataset versions use `SET NULL`.
- **Administrative audit:** `admin_audit_logs` and `admin_account_deletion_requests` intentionally use scalar actor/target IDs rather than Auth foreign keys, preserving audit/deletion history independently of account deletion.

- A profile and settings row are associated with one Auth user.
- A family has one unique owner; a user may belong to at most one family. Family owner/member roles drive access.
- Family invitations have unique token hashes and a partial unique constraint for one pending invitation per family/email; they are owner-controlled, expiring, revocable, and single-use.
- A scan belongs to a user. Threat/provider/module evidence and notifications must remain associated with the correct scan and owner.
- A scam report is visible to its author and, subject to family sharing settings, eligible family members.
- Each alert targets exactly one user or one family and may reference its originating scan or report.
- Alert read state is per user; reading an alert must not change another user's state.
- Quota, reservation, deduplication, cooldown, provider runtime, audit, and administrative records are server-controlled.
- Trusted examples progress through user submission, review/verification, evaluation, and restricted dataset release.
- Account deletion has related files, profile/settings, membership, scans, reports, alerts, and audit/deletion records to reconcile.

## 4. Views, RPCs, triggers, and scheduled work

### Views

The migrations define operational/admin views: `provider_health_daily`, `detection_feedback_daily`, `ai_provider_health`, `admin_user_directory`, `admin_family_directory`, `admin_dashboard_daily`, `admin_family_security_events`, `admin_family_membership_directory`, and `admin_family_invitation_directory`.

These are not portable PostgreSQL objects. Rebuild only the needed projections using Appwrite queries, Functions, or scheduled materialized summaries, with administrator-only access enforced server-side.

### PostgreSQL RPC inventory

The migrations contain 44 function declarations/replacements across the history, representing these unique function names:

- **Family/auth/profile/alert:** `is_family_member`, `is_family_owner`, `are_family_members`, `can_view_alert`, `add_family_owner`, `sync_profile_from_auth`, `create_scan_alert`, `create_report_alerts`, `create_family_invite`, `consume_family_invite`.
- **Quota, scan persistence, cleanup:** `consume_threat_analysis_quota`, `consume_url_reputation_quota`, `consume_scam_intelligence_quota`, `consume_threat_provider_quota`, `record_threat_scan`, `prune_threat_lookup_cache`, `prune_analysis_data`, `delete_expired_scan_history`.
- **MFA/RLS:** `mfa_access_allowed`.
- **Trusted intelligence:** `stage_trusted_example`, `activate_trusted_dataset`.
- **AI request controls:** `reserve_ai_provider_attempt`, `record_ai_provider_attempt`, `reserve_ai_provider_attempt_v2`, `record_ai_provider_attempt_v2`.
- **Notification idempotency:** `mark_notification_scan_result_deleted`, `reserve_notification_scan`, `release_notification_scan`, `record_notification_threat_scan`, `delete_expired_notification_scan_idempotency`.
- **Other backend controls:** `touch_user_settings_updated_at`, `initialize_user_settings`, `consume_edge_request_window`, `reject_admin_audit_log_mutation`.

Source-level grant statements explicitly grant the four family-visibility helpers to `authenticated`. Quota, persistence, invite, AI reservation/accounting, notification-idempotency, retention, edge-window, and trusted-intelligence RPCs have explicit `service_role` grants. Trigger-only functions are revoked from public/client roles in the migrations. This is a **source-level inventory**, not an effective ACL audit: PostgreSQL default function privileges and migration execution order mean actual `pg_proc`/role grants must be checked against an isolated database before relying on these statements. The `mfa_access_allowed()` definition has no explicit revoke in the reviewed migration source; a previous read-only security review flagged its default `PUBLIC EXECUTE` as a verification/hardening item, not a confirmed exploitable vulnerability.

### Triggers

The migrations define triggers to:

1. Add the family owner as a membership when a family is created.
2. Synchronize profile data from Auth-user changes.
3. Initialize settings for a new Auth user and update settings timestamps.
4. Create alerts for scan results and scam reports.
5. Mark notification scan idempotency state when a scan result is deleted.
6. Reject mutation of append-only admin audit logs.

Appwrite does not automatically migrate PostgreSQL triggers. Recreate each behavior as an idempotent server-side operation or Function, and test partial failures/races.

### Scheduled jobs

Two `pg_cron` jobs are defined:

- `delete-expired-scan-history`, scheduled at `15 2 * * *`, invokes `delete_expired_scan_history()`.
- `delete-expired-notification-scan-idempotency`, scheduled at `20 2 * * *`, invokes `delete_expired_notification_scan_idempotency()`.

No evidence of a separate scheduled Edge Function was found. The existing schedules do not establish which jobs are installed in a deployed database. Appwrite Functions must replace and be tested for these retention windows; do not silently discard retention or idempotency guarantees.

## 5. RLS, roles, and authorization boundaries

The SQL source defines row-level policies for self-owned profile/settings/scan/alert state, family membership/owner operations, report sharing, scan evidence, feedback, community/trusted intelligence, and admin-only views/audit. A later MFA migration adds restrictive MFA checks to user-data tables; another migration makes the privileged-role policy require a verified factor and AAL2 in Supabase.

### Named policies in migration source

The checked-in migrations enable RLS on all 38 public application tables. The named client-facing policies are:

| Supabase object | Policy names |
|---|---|
| `profiles` | `profiles_read`, `profiles_update_self` |
| `families` | `families_select_member`, `families_insert_self`, `families_update_owner`, `families_delete_owner` |
| `family_members` | `family_members_select_member`, `family_members_delete_member` |
| `family_invites` | `family_invites_select_owner` |
| `scan_records` | `scan_records_select_self`, `scan_records_insert_self`, `scan_records_delete_self` |
| `scam_reports` | `scam_reports_select_author_or_family`, `scam_reports_insert_self`, `scam_reports_delete_self` |
| `alerts` | `alerts_select_visible` |
| `alert_reads` | `alert_reads_select_self`, `alert_reads_insert_visible`, `alert_reads_update_visible` |
| `user_settings` | `user_settings_select_self`, `user_settings_update_self` |
| `threat_scan_results` | `threat_scan_results_select_self` |
| `threat_provider_results` | `threat_provider_results_select_self` |
| `detection_feedback` | `detection_feedback_select_self`, `detection_feedback_insert_self` |
| `analysis_module_results` | `analysis_module_results_select_self` |
| `community_threat_reports` | `community_threat_reports_select_self` |
| `example_submissions` | `example_submissions_select_owner`, `example_submissions_select_reviewer` |
| `example_verifications` | `example_verifications_select_reviewer` |
| `example_admin_overrides` | `example_admin_overrides_select_admin` |
| `dataset_versions` | `dataset_versions_select_reviewer` |
| `intelligence_audit_logs` | `intelligence_audit_logs_select_admin` |
| `storage.objects` in `profile-avatars` | `profile_avatars_read_own`, `profile_avatars_insert_own`, `profile_avatars_update_own`, `profile_avatars_delete_own`, `profile_avatars_read_family` |

The restrictive policy named `mfa_required_for_opted_in_users` is dynamically installed on these 22 tables: `profiles`, `families`, `family_members`, `family_invites`, `scan_records`, `scam_reports`, `alerts`, `alert_reads`, `user_settings`, `threat_scan_results`, `threat_provider_results`, `threat_lookup_cache`, `threat_provider_daily_usage`, `analysis_module_results`, `community_threat_reports`, `detection_feedback`, `example_submissions`, `example_verifications`, `example_admin_overrides`, `dataset_versions`, `trusted_training_examples`, and `intelligence_audit_logs`. The policy name is the same on each table. The later admin migration replaces several trusted-intelligence policies with updated role checks.

The other RLS-enabled application tables have no client-facing row policy in the checked-in migrations and are intended for server-only access; confirm effective grants in an isolated database. This includes quota/usage state, provider/cache state, internal classification/audit data, AI request reservations, notification idempotency, edge request windows, and admin-only records.

Trusted privileged roles are `super_admin`, `admin`, `moderator`, and `support_admin`. Laravel assigns them through server-side Supabase `app_metadata`; signup/client-editable user metadata is not the role authority. The `scam-intelligence` Function independently reads the Auth user and checks role/MFA for privileged moderation and release actions. Both Edge Functions require gateway JWT verification.

Appwrite's permissions are grants. Table-level grants can broaden access beyond row-level permissions; server integrations/API keys can bypass normal resource permissions. Therefore:

- Enable row security and use explicit row/file permissions for client-accessible records; do not grant broad table-level read/update/delete.
- Keep quotas, idempotency, provider state, trusted-dataset release, admin roles, audit logs, deletion review, and all privileged mutations inaccessible to client sessions.
- Every Function must authenticate its caller and independently enforce user ownership, family relationship, verified email where required, trusted role, MFA, quotas, and request validation.
- The Appwrite API key must be server-only and least-scoped. Never bundle it in Flutter or browser JavaScript.
- Keep a server-owned privileged-role source; user preferences, labels, or editable profile fields must not grant roles.

**MFA blocker:** Appwrite documents verified email/phone/TOTP factors and a `user_more_factors_required` login flow, but this inspection did not establish a Supabase AAL2-equivalent assurance signal for every Function invocation. Before replacing privileged access, test whether an Appwrite user JWT/session created after only the first factor can call a privileged Function. Require a fail-closed server-side proof that MFA completed, and test factor removal, recovery codes, expired challenges, session refresh, and role changes. If this equivalence cannot be demonstrated, do not cut over privileged operations.

## 6. Edge Functions, providers, Storage, Realtime, and native monitoring

### Supabase Edge Functions

| Function | Current responsibilities | Appwrite mapping |
|---|---|---|
| `scam-intelligence` | Message/URL/screenshot-text scan; AI assistant; URL reputation; scan persistence and quotas; community indicator reporting; trusted-example submission/listing/review/dispute/evaluation/release; account deletion | One or more Appwrite Functions organized by trust boundary. Keep expensive/external operations, quotas, role checks, evidence validation, and account deletion on the server. |
| `family-invitations` | `invite`, `revoke`, and `accept`; validates authenticated user/family rules and uses atomic invitation RPCs | Appwrite Function(s) preserving expiry, revocation, single-use acceptance, membership uniqueness, and server-side authorization. |

The current provider pipeline includes Gemini, Groq, OpenRouter, Mistral, and Hugging Face for AI; URLhaus, Google Safe Browsing, AlienVault OTX, OpenPhish, PhishTank, URLScan, ThreatFox, VirusTotal, and Pulsedive for reputation. The repository has provider configuration/status documentation and mocked/unit tests. This audit made no provider requests and does not attest that any provider is currently configured or reachable.

### Storage

The `profile-avatars` bucket is private. SQL policies scope object operations to the user's folder and permit family reads; migrations specify image formats and a 5 MB limit. Appwrite Storage must preserve private-by-default access, owner-only mutation/deletion, scoped family reads, accepted file types/size, and deletion cleanup. Test unauthenticated, cross-user, cross-family, update, and delete requests using an isolated Appwrite project.

### Realtime

The dashboard repository subscribes to `alerts` with a Supabase stream. Migrations publish `alerts` and `family_members`; the Flutter repository's observed stream is alerts. Appwrite Realtime can replace this subscription only after confirming that channels and row/file permission filtering meet the same privacy boundary. Realtime delivery is not authorization by itself.

### Android notification monitoring

`MessageNotificationListenerService`, `SensitiveNotificationFilter`, `NotificationQueueStorage`, access/revocation helpers, and queue-expiry behavior are Android-native. The listener filters and queues locally; notification-derived scans use a server idempotency key before analysis. Keep consent, privacy filtering, revocation, queue expiry, and OS-level notification access local. Migrate only the server-side scan/idempotency behavior, never the Android listener into Appwrite.

## 7. Laravel Super Admin

Laravel currently uses a custom `SupabaseAdminClient` rather than a Supabase PHP SDK. It handles password/refresh-token sessions, user lookup/logout, factor listing/enrollment/challenge/verification, password recovery/update, trusted role lookup from `app_metadata`, and Auth Admin API operations. `SupabaseAdminRepository` reads the admin directory/dashboard/family/security/invitation views and writes audit/deletion records. Admin controllers manage roles, user suspension, family/security review, provider/system state, audit history, and deletion requests.

Target replacement: official Appwrite PHP SDK on the Laravel server, with browser session secrets protected by Laravel, server-to-server calls behind authenticated admin routes, and independent server-side role/MFA checks. The Appwrite server key stays in server environment configuration. Any endpoint that accepts an Appwrite user JWT must retain user permissions; use elevated server credentials only for explicitly authorized administrative work, never as a substitute for checking the actor.

## 8. Existing test and documentation evidence

- `supabase/tests` contains 10 Node test files and two pgTAP SQL files. Node tests use mocks/static source assertions for auth hardening, MFA helpers, family invitation quotas, request bodies, scan analysis, provider behavior, trusted intelligence, and notification idempotency.
- The SQL files declare pgTAP plans of 17 assertions (`security_boundaries.test.sql`) and 14 assertions (`notification_scan_idempotency.test.sql`). Those are repository test definitions, not proof they ran during this audit.
- Flutter and Laravel tests are not Appwrite integration tests.
- No tests were run for this documentation-only Phase 1. Prior environment checks in this session found no global Supabase CLI or `psql`, and the Docker daemon was unreachable; this audit did not start containers or connect to a hosted backend.
- `docs/CYVORA_ARCHITECTURE.md` references `202611230001_preserve_scan_history.sql`, which is absent from the 27-file migration directory. Reconcile this documentation drift before using that document as the authoritative retention history.
- `supabase/README.md` and `docs/SUPABASE_LOCAL_SETUP.md` include historical local test/setup information; historical results were not reproduced for this audit.

## 9. Appwrite migration constraints and unresolved items

The official [Supabase-to-Appwrite migration guide](https://appwrite.io/docs/advanced/migrations/supabase) describes a Console migration wizard and warns that PostgreSQL functions, advanced indexes, and scheduling are not migrated; Supabase OAuth users are not migrated; and Functions require manual porting. It also describes use of Supabase database credentials and a `service_role` key for source-file migration. **Do not run that wizard against production or expose source credentials.** Use only an owner-approved isolated copy/export in a non-production migration exercise.

Before any implementation/cutover, resolve:

1. Whether Supabase Auth password hashes, user IDs, verified status, MFA factors/recovery state, and sessions can be migrated. Never export plaintext passwords. OAuth users will need provider re-authentication per Appwrite's migration guide.
2. The exact Appwrite version/hosting plan, region, database/table IDs, bucket IDs, Function runtimes, API key scopes, web origins, Android application ID, and iOS bundle ID.
3. How Appwrite Functions prove completed MFA for privileged requests; how privileged roles are stored and granted/revoked server-side.
4. Whether TablesDB transactions and uniqueness/atomic-number operations can preserve quota reservation, request deduplication, invitation limits, and notification idempotency under contention.
5. How data export/import preserves IDs, ownership, file ACLs, timestamps, JSON/array fields, retention, audit integrity, and account-deletion semantics.
6. The actual deployed Supabase schema/grants/RLS/job state and data counts, assessed only in an explicitly isolated staging copy.
7. A rollback and reconciliation plan that keeps Supabase unchanged as the authoritative backend until Appwrite staging verification is complete; no permanent dual-backend design is proposed.

## Phase 1 conclusion

**PASS — source-level component inventory and provisional Appwrite mapping are documented.**

**BLOCKED — live Supabase catalog/RLS validation and account-migration behavior are not established.**
**NOT TESTED — no Appwrite project, migration, provider connectivity, or Appwrite integration test was run.**

No application code, dependency manifest, Supabase resource, production data, or Appwrite resource was changed.
