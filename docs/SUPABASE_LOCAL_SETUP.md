# Cyvora Supabase Local Setup

## Current state

Docker Desktop 4.90.0, Engine 29.7.2, Compose 5.5.1, and Ubuntu WSL 2 Docker
integration were verified on 2026-11-17. Supabase CLI 3.1.0 runs through
`npx.cmd`; it is not globally installed. `supabase status` currently fails
because the local Supabase database container is absent.

The configured project ID matches three retained Docker volumes and a
Supabase network. **Do not run `supabase db reset` from the repository's
current `supabase` directory**: resetting it may overwrite local database
contents. The Docker host also had less than 1 GB free memory during
diagnostics. See [the environment audit](./DOCKER_ENVIRONMENT_AUDIT.md).

## Prerequisites

- Docker Desktop with the WSL 2 engine running.
- Working Docker Compose plugin.
- Node.js and the `npx.cmd` shim.
- Enough free host memory to run the full Supabase service set.
- A disposable local project ID, not a linked hosted/production target.

The repository's `.temp` state is not copied into the isolated work directory.
The CLI version recorded locally is 3.1.0; CLI 3.2.0 was advertised as
available but was not validated for this project.

## Safe isolated workflow

The following PowerShell commands make a temporary Supabase work directory
containing only config, migrations, SQL/Node tests, and functions. Before
starting, edit `config.toml` **in that copy only** and change `project_id` to a
unique value that has never been used on this Docker host.

```powershell
# Run from the repository root.
$testRoot = Join-Path $env:TEMP ("cyvora-supabase-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot | Out-Null
Copy-Item .\supabase\config.toml $testRoot
Copy-Item .\supabase\migrations, .\supabase\tests, .\supabase\functions -Destination $testRoot -Recurse

# Manually edit only:
#   $testRoot\config.toml
# Change project_id to a unique disposable ID. Do not copy .temp, .branches,
# .env files, or any production credentials.
Set-Location $testRoot
npx.cmd --yes supabase@3.1.0 start
npx.cmd --yes supabase@3.1.0 status
npx.cmd --yes supabase@3.1.0 db reset
npx.cmd --yes supabase@3.1.0 test db
npx.cmd --yes supabase@3.1.0 stop
```

`db reset` is destructive to the selected **local** database. Run it only
after confirming the current directory is the isolated copy and its project
ID is unique. Never add `--linked`, and never run against production.
`supabase status` can print local API keys; redact them before sharing output.
Stopping the stack does not authorize deleting Docker volumes. Preserve them
unless the owner explicitly approves targeted cleanup.

## Database validation scope

- There are 24 ordered migrations through `202611170007`.
- The migrations require `pg_cron` for retention cleanup.
- The SQL tests are pgTAP suites in `supabase/tests/`; fixtures are wrapped in
  transactions and rolled back.
- The security-boundary suite covers RLS, family isolation, RPC permissions,
  invitation behavior, and AI quota reservation.
- The notification idempotency suite covers duplicate reservations, retries,
  replay, deletion tombstones, and cleanup scheduling.
- Previous disposable Supabase PostgreSQL 17.11.0.018 validation applied the
  migrations and passed 27 pgTAP assertions. That historical result does not
  verify the currently stopped local project.

After the local database suites, run the application tests:

```powershell
node --experimental-strip-types --test .\supabase\tests\*.test.mjs
Set-Location .\flutter
flutter test --no-pub --concurrency=1
```

On 2026-11-17 the Node suite passed 96 tests and Flutter passed 66 tests. The
local Supabase CLI stack and pgTAP suites were not run during that audit.
