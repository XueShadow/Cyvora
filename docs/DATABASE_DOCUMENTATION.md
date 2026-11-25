# Cyvora Database Documentation

## Core tables

- `profiles`: account display names.
- `families`, `family_members`, `family_invites`: family ownership/membership.
- `scan_records`: scan metadata, not original private input.
- `scam_reports`: user/family reports.
- `alerts`, `alert_reads`: user/family alert state.
- `user_settings`: privacy and scan-retention preferences.
- `threat_analysis_usage`, URL/reputation/scam quotas: server counters.
- `threat_scan_results`, provider results and module evidence: threat metadata.
- `edge_request_windows`: atomic 10-request/10-minute AI window.
- `ai_*` tables: provider/global/user budgets and reservations.
- `notification_scan_idempotency`: notification scan replay and leases.
- Trusted-intelligence and admin tables: moderated evidence and audit state.

## Retention

Scan history defaults to 90 days and supports 30, 60, or 90 days. The cleanup
function deletes a record only when it is older than the owner's setting.
Notification queues use local 1/7/30-day retention. Notification scan
idempotency records are cleaned through pg_cron. Existing data is not reset by
the hardening migration.

## Constraints and indexes

Migrations define primary keys, foreign-key cascades, unique family-owner and
family-member constraints, invitation uniqueness, quota checks, and user
history indexes. Detailed operational verification requires a running database.
