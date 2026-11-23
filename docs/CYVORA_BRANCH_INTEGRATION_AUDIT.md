# Cyvora Branch Integration Audit

**Audit date:** 2026-11-23  
**Status:** Phase A inventory and Phase B audit complete; the selective merge is resolved locally, pending the merge commit and database validation.
**Scope:** Read-only comparison of `main`, `fix/mlkit-release-crash`, and `security/complete-production-hardening`. This is not a full security audit or production-readiness certification.

## Executive summary

The three refs share `83fba3c` as their merge base and have diverged. `main` is an ancestor of both feature branches. The `fix` branch contains the Laravel Super Admin panel and mandatory privileged-account MFA. The `security` branch contains Android release safeguards, notification-scan persistence, Supabase Auth schema compatibility, and additional audit/evaluation documentation.

Do **not** merge the security branch as-is. Its Edge Function MFA helper no longer requires privileged accounts to enroll a factor, and its scam-intelligence role checks remove `super_admin`. It also removes MFA and audit-log immutability assertions from the SQL boundary tests. Separately, the current `fix` branch's notification idempotency migration does not return `reserved` for a new reservation, contrary to its SQL test. The integration branch retains the fix-branch MFA/role protections and tests, keeps the stricter `170005` schema, and adds forward migrations `170006` and `170007`. The migrations have not been applied to a database.

The source refs remain unchanged. A new `integration/production-hardening` branch was created from `fix/mlkit-release-crash`, with backup refs for all three audited refs. The security branch is merged locally with conflicts resolved; the merge commit and push are pending. The pre-existing dirty changes remain preserved and unstaged.

## Branch topology and ownership

| Ref | Tip | Commits after merge base | Primary contribution |
|---|---|---:|---|
| `main` | `83fba3c` | 0 | Shared baseline |
| `fix/mlkit-release-crash` | `e36c48f` | 8 | Android ML Kit release fix; dashboard request coalescing; Laravel Super Admin panel; privileged MFA; notification scan idempotency and tests |
| `security/complete-production-hardening` | `8247268` | 14 | Protected Android release workflow; notification queue persistence/idempotency; migration compatibility/fix; ML Kit rules; security, staging, Docker, and synthetic evaluation reports |

`fix` and `security` are siblings, not a fast-forward pair. The tree-to-tree comparison reports 108 changed paths, but many removals are simply fix-only additions (not deletion commits in the security branch). In particular, Laravel files added by `fix` are absent from the shared base and were not removed by `security`.

### Changed-file inventory

- `main...fix`: 90 files, 8,086 insertions, 382 deletions. The largest areas are `laravel/` (admin authentication, authorization, management, Supabase services, UI, and tests), `supabase/` (MFA, admin schema, Edge Function authorization, idempotency, and tests), Flutter MFA/notification/dashboard changes, and Super Admin/readiness documentation.
- `main...security`: 48 files, 2,786 insertions, 200 deletions. The main areas are Android release workflow and queue handling, Supabase migrations/functions/tests, and new or updated security, staging, Docker, release, and scam-evaluation documents.
- The branches both change `README.md`, architecture/readiness/test reports, Supabase MFA/scam-intelligence code, notification migration/tests, Flutter dashboard code/tests, and release version metadata. Those overlaps need content-aware reconciliation rather than wholesale document or directory replacement.

## Key differences and merge risks

### 1. Privileged MFA enforcement — **resolved in integration branch**

In `fix`, `mfaBlockReason` returns `enrollment_required` for privileged roles without a verified factor and requires AAL2 for accounts that have a verified factor. In `security`, `requiresMfaChallenge` only returns true when a verified factor exists and the token is not AAL2. A privileged account with no verified factor therefore passes this helper at AAL1. The affected Edge Function uses a service-role Supabase client, making this authorization check particularly important.

The security branch also removes `super_admin` from `hasTrustedReviewRole` and `hasTrustedAdminRole` in `scam-intelligence`. That would deny the Super Admin panel's trusted moderation/release operations. Its `security_boundaries.test.sql` drops from 17 assertions to 13, removing the privileged MFA and immutable-admin-audit assertions; it also lacks the fix branch's `mfa-auth.test.mjs`.

**Resolution:** the integration branch retains the `fix` MFA helper and `super_admin` review/admin roles, and preserves all 17 SQL boundary assertions. It adds regression coverage for all privileged roles, client-controlled metadata, and the locked no-factor Flutter screen. The insecure helper remains only on the untouched `security` and backup refs.

### 2. Notification scan idempotency — **source fix added; database validation pending**

The `fix` version of `202611170005_notification_scan_idempotency.sql` inserts a new row without using `RETURNING` to return the new lease. It then reads the still-active row and reports `processing`; the SQL test expects the first call to report `reserved`. The security branch corrects the reservation path and adds `202611170007_notification_scan_reservation_initial_lease.sql` as a forward fix for databases where the earlier migration has already been applied.

The integration keeps the fix branch's stricter constraints, cleanup behavior, and deletion handling in `170005`, and adds `170007` as a forward-only replacement for the reservation function. It does not rewrite the historical migration. Establish the target database migration ledger and run the SQL tests against a disposable database before applying it anywhere. No current migration ledger was available in this audit.

### 3. Family-invitation Auth schema compatibility

`security` adds `202611170006_family_invite_auth_compat.sql` to handle Supabase Auth schemas exposing either `email_confirmed_at` or `confirmed_at`, and adjusts the invitation RPC authorization boundary. The integration includes this forward migration but leaves historical `202606120001_dashboard_mvp.sql` unchanged.

### 4. Mobile/release behavior

- Keep the higher `flutter/pubspec.yaml` version from `fix` (`1.0.3+3`); `security` resets it to `1.0.2+2`.
- The ML Kit ProGuard additions are present in both branches and should be retained.
- The security release-workflow test expansion is additive, but its GitHub environment/secrets and required-protection settings still need verification.
- `fix` adds dashboard summary-request coalescing. The security-branch snapshot lacks that fix-only addition; the merge keeps the coalescing while also retaining the security branch's notification messaging.
- Security's 26 hand-authored synthetic scam examples are useful deterministic regression fixtures, not a representative or held-out accuracy evaluation. Its own evaluation report correctly cautions against interpreting perfect fixture scores as production accuracy.

### 5. Documentation and generated files

- The integration root README now identifies Laravel as the official Super Admin panel and links its guide.
- Both branches revise several of the same audit/readiness/test reports. Security-branch documents should be reconciled with current code and rerun evidence rather than copied as a set. Existing reports also disagree on whether particular pgTAP suites were rerun and on assertion counts; use fresh, commit-specific test output as the source of truth.
- `supabase/.temp/cli-latest` is generated local state; the merge restores the integration branch's original value rather than adopting the security branch's version bump.
- The security branch does not contain the Laravel panel because it was not part of its base; that is not evidence that Laravel is unused or should be removed.

## Migration inventory

`main` contains migrations through `202611170004_ai_request_dedup_quota_reservation.sql`.

`fix` adds:

- `202611170005_notification_scan_idempotency.sql`
- `202611230002_super_admin_panel.sql`
- `202611230003_require_mfa_for_admins.sql`

`security` adds or changes:

- `202611170005_notification_scan_idempotency.sql` (different implementation)
- `202611170006_family_invite_auth_compat.sql`
- `202611170007_notification_scan_reservation_initial_lease.sql`
- Historical `202606120001_dashboard_mvp.sql` (modified)

The local working tree also contains an untracked `202611230001_preserve_scan_history.sql`; it is not present in the three audited branch trees. It was inspected after the follow-up request and removes the scan-history cleanup schedule/function. It remains unstaged and unapplied; validate its intended retention policy and migration order before use.

## Follow-up fixes on the integration branch

- Added `202611170007_notification_scan_reservation_initial_lease.sql` as a forward-only replacement for the reservation function. It returns the newly inserted lease as `reserved` and leaves the historical `170005` migration unchanged.
- Added a Node regression assertion for that forward migration and expanded MFA tests to cover every privileged role and ensure user-controlled metadata does not grant privileged status.
- Added a Flutter widget test confirming that the tagged no-factor challenge screen remains locked and cannot invoke verification.
- The current `fix` branch's MFA implementation was already enforcing privileged enrollment and AAL2. It was not weakened or replaced; the insecure helper remains only on the unmerged `security` branch.
- The forward migration has not been run against a database.

## Validation evidence and gaps

- Integration validation: 102 Supabase Node tests passed; 70 Flutter tests passed; Flutter analysis passed; 15 Android release-policy tests passed; Android debug APK built.
- Historical security-branch summaries for disposable PostgreSQL tests, separate-session concurrency, and catalog checks were not reproduced; do not treat them as current integration evidence.
- The local Docker CLI is installed, but the Docker daemon is unavailable. `psql`, Supabase CLI, and Deno were not detected, so PostgreSQL/pgTAP and Edge Function checks could not be run here.
- `git diff --check` reports trailing whitespace in the pre-existing dirty `docs/CYVORA_SECURITY_AUDIT.md`; that unrelated file was not changed as part of the follow-up.
- No production/staging database, migration ledger, Supabase credentials, or GitHub workflow environment was accessed.
- The integration branch contains local commit `7d33894` and a resolved merge awaiting its merge commit. Source refs remain unchanged. Existing uncommitted changes include edits under `docs/`, `flutter/`, and `laravel/`, plus untracked local configuration/artifacts and `supabase/.temp/start-secrets/`. The contents of the secret-bearing temporary directory were not inspected.

## Recommended integration sequence

1. Keep `fix/mlkit-release-crash` as the integration base; do not alter its protected source ref.
2. Keep privileged MFA enrollment/AAL2 enforcement, `super_admin` reviewer authorization, the 17 SQL boundary assertions, and mobile version `1.0.3+3`.
3. Keep historical migration `202606120001` unchanged; use forward migrations `170006` and `170007`.
4. On isolated PostgreSQL/Supabase, test fresh install and upgrade from the recorded migration point; run SQL security/idempotency suites. Do not use production.
5. Reconcile the preserved user edits, including scan-history retention, with the migration ledger and privacy policy before staging them.
6. Only after all changes and docs are reviewed should the merge commit be finalized and pushed.

## Phase status

- **Phase A — branch and feature inventory:** complete.
- **Phase B — branch integration audit:** recorded in this document.
- **Phase C — integration branch/merge:** branch created, security branch merged locally, and conflicts resolved; merge commit pending.
- **High/medium finding follow-up:** MFA enforcement remains secure with expanded tests; forward reservation fix and UI lockout regression test are added. Database behavior is not yet verified.
- **Backup refs:** `backup/integration-20261123-main`, `backup/integration-20261123-fix`, and `backup/integration-20261123-security`.
- **Push/PR:** none.
