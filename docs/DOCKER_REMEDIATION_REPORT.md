# Cyvora Docker Remediation Report

**Date:** 2026-11-17

## Summary

No Docker Engine repair was needed: Docker Desktop, Engine, Compose, and Ubuntu
WSL integration all work. The actual blocker is that the local Supabase
containers are absent while their named volumes and network remain. Supabase
CLI status fails on the missing database container. The host also had less
than 1 GB free RAM during inspection.

No Docker configuration, application code, production service, existing
database, or Docker volume was changed. No containers were started. The
pre-existing local database volumes were intentionally preserved because
`supabase db reset` against the configured project could overwrite their
contents.

## Findings and remediation

| ID | Finding | Root cause | Fix implemented | Validation | Remaining action |
|---|---|---|---|---|---|
| DR-01 | Docker engine unavailable? **No — engine is healthy.** | The earlier concern was not reproduced: Windows Docker CLI and Ubuntu WSL both connect to Docker Desktop. | None; do not reinstall Docker or alter WSL integration. | `docker version`, `docker info`, `docker compose version`, and WSL socket test passed. | None for engine connectivity. |
| DR-02 | Supabase local stack unavailable | No Supabase containers exist, although the configured project has retained database, Edge Runtime, Storage volumes, and a network. | No destructive repair. Keep existing volumes intact; run tests from a fresh isolated project ID as described in `SUPABASE_LOCAL_SETUP.md`. | `supabase status` failed because the expected database container is absent; `docker ps -a` reports zero containers. | Owner should create an isolated local stack after ensuring adequate host memory. |
| DR-03 | Local stack startup has low resource headroom | Windows host reported 0.50–0.83 GB free RAM; Docker's Linux VM reports 4.804 GiB. | No processes were killed and Docker resource settings were not changed. | Host memory and Docker Engine information were recorded. | Close other memory-heavy applications or restart, then recheck before starting Supabase. |
| DR-04 | Supabase CLI missing from global `PATH` | CLI is not globally installed, but Node/npm command shims are available. PowerShell's `npm.ps1` is blocked by execution policy. | No global install; use `npx.cmd --yes supabase@3.1.0`. | CLI version command passed and reported 3.1.0. CLI advertises 3.2.0 as an update. | Pin or upgrade deliberately; no repository version pin was added. |
| DR-05 | No custom application Docker configuration | Repository has no Dockerfile, Compose file, or `.dockerignore`. | No files added for a custom app image; native Flutter/Android and official Supabase CLI workflows remain appropriate. | Hidden and visible repository file search found no Docker build/Compose files. | None unless a real deployment target requires a container image. |

## Test results

- Supabase JavaScript tests: **PASS — 96 tests**.
- Flutter tests from `flutter\`: **PASS — 66 tests**.
- Supabase CLI version check: **PASS — 3.1.0 resolved with `npx.cmd`**.
- Supabase local status: **BLOCKED** by the missing database container.
- `supabase start`, `supabase db reset`, and `supabase test db`: **NOT RUN**.
  The current project has retained data volumes, and free host memory was low.
- Existing separate disposable PostgreSQL evidence remains historical:
  migrations applied and 27 pgTAP assertions passed. It was not repeated here.

## Owner actions

1. Keep the existing named volumes; do not use `docker system prune`,
   `docker volume rm`, or `supabase db reset` on the current configured project.
2. Ensure adequate free host memory.
3. Follow the isolated workflow in
   [SUPABASE_LOCAL_SETUP.md](./SUPABASE_LOCAL_SETUP.md), using a copied
   Supabase work directory and a unique project ID.
4. Capture `supabase status`, migration output, and both pgTAP suite results.
   Redact local keys before sharing command output.
5. Do not deploy migrations or functions to production as part of this local
   remediation.
