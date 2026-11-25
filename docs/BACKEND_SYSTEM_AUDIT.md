# Cyvora Backend System Audit

## Status key

- **VERIFIED WORKING** — executed locally or confirmed by passing source tests.
- **VERIFIED FAILING** — observed in source/runtime evidence.
- **FIXED AND VERIFIED** — changed and covered by a passing check.
- **NOT TESTED** — no live/staging/device evidence.
- **REQUIRES EXTERNAL ACCESS** — hosted credentials, hardware, or owner settings needed.

## Architecture

Flutter MVP: View -> Presenter -> Repository -> Data Source -> Supabase.
Authentication and data operations use `AppDependencies`; feature Views do not
call Supabase directly. The dashboard repository remains a broad adapter, while
auth and profile-photo access use dedicated data sources.

Backend: Supabase Auth, PostgreSQL/RLS, Storage, and Deno Edge Functions
`scam-intelligence` and `family-invitations`.

## Component classification

| Component | Status | Evidence |
|---|---|---|
| Flutter analysis/build | VERIFIED WORKING | 76 Flutter tests and analyze pass locally |
| Supabase Edge JWT verification | FIXED AND VERIFIED | Gateway config changed to `verify_jwt = true`; source test passes |
| AI pipeline | VERIFIED WORKING IN SOURCE; LIVE NOT TESTED | 69-node suite passed before the focused rerun |
| Atomic AI budgets | VERIFIED WORKING IN SOURCE | Provider budget RPC and tests exist |
| 10 requests/10 minutes | FIXED AND VERIFIED | New atomic edge window RPC and source test |
| 50 cloud-analysis budget | FIXED AND VERIFIED IN SOURCE | Provider limit defaults to 50 where unconfigured |
| Scan retention | FIXED AND VERIFIED IN SOURCE | 30/60/90 setting and cleanup migration |
| Account deletion | FIXED AND VERIFIED IN SOURCE | Explicit Edge action and profile-avatar cleanup |
| RLS | NOT TESTED LIVE | Migration source is restrictive; hosted/PostgreSQL execution unavailable |
| Hosted Auth/MFA | REQUIRES EXTERNAL ACCESS | No hosted project credentials or dashboard access |
| Live AI providers | REQUIRES EXTERNAL ACCESS | No provider credentials/live billing verification |
| Android runtime permissions | NOT TESTED | Source/app unit tests pass; no physical device available |
| Storage bucket policies | VERIFIED WORKING IN SOURCE | Private profile avatar bucket and ownership policies |

## Critical remaining risks

1. Hosted migration/deployment revisions must be compared in staging.
2. The 10/10 and 50-budget RPCs require deployed migrations.
3. Account deletion success depends on a deployed Edge Function and service-role
   admin capability.
4. CAPTCHA is not implemented for anonymous users because this app does not
   expose anonymous sign-in or a verified anonymous abuse surface.
5. Live RLS, provider, MFA, Cron, and data-restoration behavior remain external.
