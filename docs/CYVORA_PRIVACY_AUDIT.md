# Cyvora Privacy Audit

## Verified in source

- Notification scanning requires explicit consent in the Flutter flow.
- Notification listener access is separate from notification preview storage.
- Notification previews use Android encrypted shared preferences.
- Shared consent and preview-retention preferences are enforced in tests.
- Message scans require consent before sending content to providers.
- Submission redaction removes contact details, secrets, and URL parameters.
- API credentials and service-role credentials are server-side in the
  reviewed architecture.
- Account deletion and profile/history deletion controls exist in source.

## Data retention

The current worktree removes automatic 120-day cleanup of scan history and
keeps history until user/account deletion. This behavior is source-defined and
must be reflected in deployed migration state and privacy policy.

## Remaining validation

- Verify current Supabase migration/deployment behavior.
- Verify notification title/text/metadata minimization on devices.
- Verify account deletion, export, backup purge, and provider retention.
- Verify hosted provider disclosures and DPA/retention terms.
- Verify HTTPS, secure cookies, telemetry, logs, and third-party SDK behavior.
- Confirm backup and incident-retention schedules.
