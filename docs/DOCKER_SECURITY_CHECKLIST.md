# Cyvora Docker Security Checklist

**Review date:** 2026-11-17

## Current assessment

There is no project Dockerfile, Compose file, or `.dockerignore`. Cyvora does
not need a custom application image for the current Flutter/Android workflow;
use the official Supabase CLI-managed local stack for Supabase development.
No containers were running during this review, so runtime settings of the
Supabase-generated containers could not be inspected.

| Control | Status | Evidence / action |
|---|---|---|
| Root execution | NOT REVIEWABLE | No project image or running project container. Do not infer the effective user of CLI-managed services from repository files. |
| Privileged mode / Linux capabilities | NOT REVIEWABLE | No Compose or Dockerfile configuration exists; no running container configuration was available. |
| Host filesystem mounts | NOT REVIEWABLE | No active containers or project Compose mounts. |
| Published ports / public database exposure | PASS FOR OBSERVED STATE | Zero containers and no listeners on checked local app/Supabase ports. Recheck firewall and bindings when starting the local stack; do not expose admin/database services to a public interface. |
| Secrets in images/configuration | PASS FOR REPOSITORY DOCKER FILES | No Docker build context exists. `laravel/.env` is ignored and not tracked. Do not copy `.env`, Supabase `.temp`, service-role keys, or provider keys into a test context. |
| Image pinning / base-image vulnerabilities | NOT APPLICABLE TO CUSTOM IMAGE | No custom Dockerfile. The Docker cache contains version-tagged Supabase images, but the repository does not pin their digests. CLI-managed image selection follows the CLI version; pin the CLI for reproducibility and review upstream image updates deliberately. |
| Health checks | NOT REVIEWABLE | No active Supabase containers; health-check behavior was not verified. |
| Unnecessary services | NOT APPLICABLE TO APP IMAGE | No app image exists. Use Supabase CLI's required local services rather than adding an improvised PostgreSQL Compose stack. |
| Network isolation | PARTIALLY VERIFIED | Only Docker's standard networks and one retained Supabase project network were listed. No custom application network exists. |
| Persistent volume permissions/data | PRESERVE | Three Supabase volumes remain without containers. They may contain local database/storage state; no inspection of contents, reset, prune, or deletion was performed. |
| Docker daemon endpoint | PASS | Local Docker Desktop context/WSL socket; no remote Docker endpoint was selected. |

## Before starting a local stack

- Use a copied Supabase work directory with a unique `project_id`; do not
  reset the current configured project because its volumes already exist.
- Keep the stack for local development only. Bind services only to the local
  machine and do not forward PostgreSQL, Studio, or administrative ports to
  the Internet or an untrusted LAN.
- Never mount production credential files. Use local-only test accounts and
  dummy secrets.
- Keep Docker Desktop and Supabase CLI maintained. The CLI version validated
  for command execution here was 3.1.0; 3.2.0 was advertised but not tested.
- Recheck actual container users, capabilities, mounts, published ports,
  image digests, health, and volume ownership after the isolated stack starts.
- Do not use `docker system prune --volumes` or delete named volumes without
  explicit owner approval.

The user-provided Docker Scout screenshot remains unverified and is not
attributed to any local Supabase image or Cyvora artifact; see
[the separate image scan review](./CYVORA_DOCKER_IMAGE_ANALYSIS.md).
