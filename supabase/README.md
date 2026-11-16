# Supabase backend

Cyvora uses Supabase Auth, PostgreSQL, Row-Level Security, and Edge Functions.
Migrations and functions are kept in this directory; the Flutter client calls
the centralized `scam-intelligence` and `family-invitations` functions.

## Local setup and secrets

Install the Supabase CLI and Deno before running local Edge Function or database
tests. Neither tool was available in the audit environment, so live function,
RLS, and family integration behavior remains unverified.

[`supabase/.env.example`](.env.example) lists optional provider variable names
with empty values. It is a reference only: do not put real keys in this file,
Flutter, Git, chat, or test fixtures. Configure Edge Function secrets through
the Supabase Dashboard or an authenticated CLI session. Keep
`SUPABASE_SERVICE_ROLE_KEY` server-side; never include it in mobile builds.
The Flutter app uses only the existing project URL and publishable/anon key.

AI providers remain disabled unless explicitly selected with a provider order,
model ID, API key, and enabled flag. Configure at most one primary and one
fallback. Verify current model availability, account terms, and pricing before
enabling a provider. Ollama is intentionally excluded.
AI calls also fail closed unless positive global, per-user, and per-provider
daily request limits are configured (up to 100,000 per limit). These are
request-count limits, not currency/billing caps; configure provider-side spend
controls separately. The guardrail migration must be applied to an approved
staging environment before enabling budgeted AI.

See [provider and capability status](PROVIDER_STATUS.md) for what is mocked,
configured, or still unverified, and
[trusted intelligence](TRUSTED_INTELLIGENCE.md) for the reviewed-example
workflow.

## Tests

Run the backend's Node tests from the repository root:

```powershell
$testFiles = Get-ChildItem .\supabase\tests\*.test.mjs | ForEach-Object { $_.FullName }
node --experimental-strip-types --test $testFiles
```

These are local unit tests using synthetic examples, mocked providers, and
static migration-contract checks; they do not execute migrations, test live
provider behavior, exercise RLS, or verify concurrent requests against
PostgreSQL. Use an isolated local or staging Supabase project with separate
test accounts for authorization and family-isolation tests. Never use
production credentials for automated tests.

## Database and function deployment

Do not run `supabase db push` or deploy functions against production as part of
local development or CI. Review migration history and the target project
carefully, and validate changes in an isolated staging project first. A
production migration or secret change requires explicit authorization and an
independently reviewed deployment plan. No production migration or function
deployment was performed in this audit.

See [the production readiness report](../docs/CYVORA_PRODUCTION_READINESS.md)
and [security notes](../docs/SECURITY.md) for outstanding verification and
operational risks.
