# Trusted scam intelligence

## Security and review flow

Scam examples are submitted through the `scam-intelligence` Edge Function. It verifies the caller, checks ownership of any linked scan, redacts contact details, authentication codes, secrets, and URL query strings, and stores the redacted content with a content hash. Automated screening records suggested rule features only; it never verifies or approves an example.

Only a server-assigned Supabase `app_metadata.role` of `moderator` or `admin` can access the review queue. Moderators cannot review their own submissions. Both scam and legitimate labels require two distinct moderators and evidence. Conflicts are excluded from trusted data; an administrator can resolve a disputed example with an audited override. Example content and verification records cannot be written directly by authenticated clients.

To assign a reviewer, a project owner must set the user's **App Metadata** in the Supabase Dashboard, for example:

```json
{"role":"moderator"}
```

Use `{"role":"admin"}` only for trusted project administrators. Never set these roles in user-editable metadata or expose a service-role key to the application. Users need a refreshed session after a role change.

## Staging, evaluation, and release

Verified examples enter a versioned, staged dataset. Staged examples do not affect scan results. Dataset snapshots use a database sequence rather than transaction timestamps, and activation is serialized with a database constraint enforcing at most one active version. The adaptive module uses only training-split examples from the currently active dataset; it compares existing rule categories and can add a suspicious review signal, but cannot independently produce a malicious verdict.

Dataset evaluation uses a deterministic hash-based train/test split and a bounded category-similarity classifier. An administrator may activate a version only after the held-out results pass all release gates: at least 20 training and 5 test examples, at least 5 training and 2 test examples of each label, accuracy >= 0.80, precision >= 0.80, recall >= 0.70, and false-positive rate <= 0.10. Evaluation is bounded to 1,000 examples. A failed or undersized version remains staged. Activating a passed version retains the previous version as a rollback target.

This is an explainable, lightweight pattern-similarity system, not foundation-model training. It learns from verified examples only after moderator approval, and production use still requires a separate administrator evaluation and release.

## Deployment and verification

Apply `202611150003_trusted_scam_intelligence.sql` and deploy the updated `scam-intelligence` Edge Function together. Do not activate a dataset before the migration and function are deployed. Test locally with:

```powershell
$testFiles = Get-ChildItem .\supabase\tests\*.test.mjs | ForEach-Object { $_.FullName }
node --experimental-strip-types --test $testFiles
```

The review queue and dataset controls are available from the profile's **Community scam intelligence** entry for users whose server-issued App Metadata contains the appropriate role.
