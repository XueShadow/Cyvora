# Cyvora Docker Environment Audit

**Audit date:** 2026-11-17
**Environment:** Windows, Docker Desktop with WSL 2
**Production access:** None. No production service, database, or credential was used.

## Verdict

**DOCKER ENVIRONMENT PARTIALLY WORKING; MANUAL CONFIGURATION REQUIRED.**

Docker Desktop, the Linux engine, Compose, and Docker access from Ubuntu WSL are
healthy. The local Supabase stack is not running. Its database, Edge Runtime,
and Storage volumes and network remain, but the containers are absent. Supabase
CLI status therefore fails when it tries to inspect the missing database
container. The existing project volumes were preserved; no database reset,
volume deletion, or stack startup was attempted.

## Environment diagnosis

| Check | Result | Evidence |
|---|---|---|
| Docker Desktop | **PASS** | Desktop process is running. Docker server identifies as Docker Desktop 4.90.0. The installation is user-scoped; the Windows `com.docker.service` service is not registered, but this does not prevent engine access. |
| Docker CLI | **PASS** | `docker --version` reports 29.7.2. |
| Docker Engine/context | **PASS** | Active Windows context is `desktop-linux`, connected through the local Docker Desktop named pipe. `docker info` reports Engine 29.7.2, Linux/amd64, WSL2 kernel, 8 CPUs, and 4.804 GiB engine memory. |
| Docker Compose | **PASS** | `docker compose version` reports v5.5.1. |
| Docker containers | **PASS / EMPTY** | `docker ps -a` reports zero containers. No application ports are published by containers. |
| WSL 2 | **PASS** | WSL default version is 2. `docker-desktop` and `Ubuntu` are both running as version 2 distributions. |
| Ubuntu WSL integration | **PASS** | In Ubuntu, `/usr/bin/docker` reports 29.7.2, connects to the Docker Desktop server, Compose is v5.5.1, and `/var/run/docker.sock` exists as a socket. |
| Linux socket | **PASS** | The socket is owned by `root:docker` with mode `srw-rw----`; the WSL Docker CLI successfully uses it. |
| Host disk | **PASS** | C: had 162.20 GB free of 475.58 GB. |
| Host memory | **CONSTRAINT** | The host had 0.50–0.83 GB free of 7.71 GB during checks. Docker Engine reports 4.804 GiB available to its Linux VM. This is insufficient headroom to safely start the full Supabase service set during this audit. |
| Port conflicts | **NONE OBSERVED** | No listeners were found on the checked application/Supabase ports: 3000, 5432, 54321–54325, 54327, 54329, 8000, or 8080. |
| Docker storage | **PRESERVED** | 14 images, three Supabase named volumes, and one Supabase network are present. The volumes total 88.13 MB. No prune or deletion command was run. |

### Supabase CLI and local stack

The Supabase CLI is not installed globally/on `PATH`. `npx.cmd --yes
supabase@3.1.0 --version` successfully resolves CLI 3.1.0. The CLI reports
3.2.0 as an available update; the repository's local CLI marker records 3.1.0.
No project CLI version is pinned in the repository.

`npx.cmd --yes supabase@3.1.0 status` **FAILED** with
`StatusDbInspectError`: the expected local Supabase database container does
not exist. Docker itself remains healthy. Docker inventory shows the matching
Supabase volumes and network without any containers. The configured local
project ID matches those retained volumes. Resetting that project could
overwrite existing local database contents, so it was not attempted.

## Repository Docker and database audit

- No `Dockerfile`, Compose YAML, or `.dockerignore` was found, including hidden
  files. There is no custom Cyvora application image to build or harden.
- Flutter/Android development should continue through Flutter and the native
  Android toolchain. A Flutter or Android container is unnecessary here.
- Supabase local development should use the official Supabase CLI stack, not
  an improvised PostgreSQL replacement.
- `supabase/config.toml` contains the project ID and two Edge Function
  settings; the CLI supplies the local service defaults. The repository has
  24 ordered SQL migrations through `202611170007`.
- The two SQL test files use pgTAP and wrap fixtures in transactions with
  rollback. Migrations `202611150006` and `202611170005` require `pg_cron`.
- Prior recorded disposable Supabase PostgreSQL 17.11.0.018 validation applied
  the migrations and passed 27 pgTAP assertions. That is historical
  PostgreSQL evidence, not proof that the currently stopped local stack is
  healthy. Seven prior independent-session reservation checks are also
  recorded separately; they were not repeated here.
- `laravel/.env` is ignored by Git and is not tracked. No Docker build context
  exists that could include it. Environment values were not printed or copied.

## Finding register

| ID | Severity | Root cause / affected component | Evidence | Fix implemented | Validation result | Remaining limitation |
|---|---|---|---|---|---|---|
| DOCKER-01 | Informational | Docker Engine connectivity | Windows and Ubuntu WSL Docker clients both reached Docker Desktop 4.90.0 / Engine 29.7.2. | None required. No engine defect found. | `docker version`, `docker info`, `docker compose version`, WSL CLI/socket checks passed. | Full Supabase stack was not started. |
| SUPA-01 | Medium | Supabase local stack absent; persisted local project volumes remain | Zero containers, three project volumes and one network; `supabase status` reports the missing database container. | No database or volume mutation. Use an isolated copy with a unique project ID before reset/test. | `supabase status` failed as described; `docker ps -a` passed and showed no containers. | Migration state and extension availability in those retained volumes were not inspected. |
| ENV-01 | Medium | Low free host memory limits safe local stack startup | Host free memory ranged from 0.50 to 0.83 GB; engine memory is 4.804 GiB. | None. No system process was stopped and no Docker memory limit was changed. | Windows memory and `docker info` measurements recorded. | Recheck after closing applications or restarting the host; do not assume the full stack will start under current pressure. |
| CLI-01 | Low | Supabase CLI is not globally installed; PowerShell blocks `npm.ps1` | `supabase` is absent from `PATH`; `npm.ps1` is execution-policy blocked, while `npm.cmd`/`npx.cmd` work. | No global install. Use the verified `npx.cmd` invocation. | `npx.cmd --yes supabase@3.1.0 --version` passed. | CLI 3.2.0 is advertised but was not tested. |

## Validation performed

| Command/check | Result |
|---|---|
| `docker --version` | PASS — Docker 29.7.2 |
| `docker compose version` | PASS — Compose v5.5.1 |
| `docker context ls`, `docker info`, `docker ps -a` | PASS — local Desktop engine reachable; zero containers |
| `wsl --status`, `wsl -l -v` | PASS — Ubuntu and Docker Desktop distributions run under WSL 2 |
| Ubuntu WSL `which docker`, `docker version`, `docker info`, `docker compose version`, `ls -l /var/run/docker.sock` | PASS — integrated CLI and socket |
| `npx.cmd --yes supabase@3.1.0 --version` | PASS — CLI 3.1.0 |
| `npx.cmd --yes supabase@3.1.0 status` | FAIL/BLOCKED — local database container absent |
| `node --experimental-strip-types --test` over `supabase/tests/*.test.mjs` | PASS — 96 tests |
| `flutter test --no-pub --concurrency=1` from `flutter\` | PASS — 66 tests |
| Supabase `start`, `db reset`, `test db` | NOT RUN — existing project volumes were preserved and host memory headroom was low |

## Limitations

No Supabase containers were started, no existing database was reset, and no
volume was deleted. Consequently this audit does not establish current local
PostgreSQL health, pgTAP installation in the stopped project volume, current
migration state, or live RLS/RPC behavior. Follow
[the isolated Supabase setup](./SUPABASE_LOCAL_SETUP.md) before running
destructive local test commands.
