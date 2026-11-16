# Cyvora security notes

**Scope:** Static review of repository code and local tests. No production
database, secret, provider credential, or live user account was accessed.
This is not a penetration test or a claim of production certification.

## Current safeguards

- Flutter uses Supabase Auth and the public publishable/anon key. Service-role
  access is restricted to server-side functions and database operations.
- Protected Edge Functions manually validate bearer tokens with Supabase Auth
  and apply MFA step-up checks before privileged operations.
- Database migrations define ownership and Row-Level Security policies.
  Family invitation consumption uses a service-role-only RPC; invitations are
  stored as hashes, expire, and require a verified matching email.
- Family invitation JSON parsing is bounded to 16 KiB. Scam analysis uses the
  same bounded request-body helper.
- URL analysis rejects private/reserved destinations from external reputation
  lookups. DNS/TLS checks do not fetch the submitted page or follow redirects.
- Optional AI and URL reputation calls are user-selected. AI routing requires
  explicit provider/model selection and limits a scan to one primary and at
  most one fallback. Provider output is validated before use. Local
  pushed code adds fail-closed global, per-user, and per-provider daily request
  limits plus a provider circuit breaker. Uncommitted follow-up adds
  user-level cooldowns, HMAC-based duplicate suppression, provider concurrency
  leases, and stops fallback after circuit-open or HTTP 429 responses. It also
  skips optional AI when verified threat intelligence is already sufficient.
  Deployment of the new follow-up migration is unverified and PostgreSQL
  execution was not tested. Request
  counts do not limit dollar spend.
- Startup diagnostics log fixed phase labels and an exception type, not the
  exception message, token, URL, or user content.

## Confirmed residual risks and unverified controls

- **Invitation rate-limit race — FIX IMPLEMENTED, DEPLOYMENT REQUIRED:** a new
  migration adds a per-family transaction advisory lock around the quota check
  and insert; the Edge Function now uses that RPC. The user reports deployment,
  but it has not been independently verified and no live concurrent-request
  test was available.
- **MFA enrollment — PARTIALLY IMPLEMENTED:** AAL2 is required for users who
  have a verified factor, but enrollment is not mandatory for all accounts.
- **Family isolation — NOT TESTED:** ownership and RLS were inspected, but
  separate-user integration tests against a local or staging database were
  unavailable.
- **Provider spend and resilience — PARTIALLY IMPLEMENTED:** local uncommitted
  changes add cooldown/deduplication/concurrency controls; pushed code already
  has atomic request-count budgets and a three-failure/15-minute circuit
  breaker. Deployment is not confirmed or live-tested, and the uncommitted SQL
  has only static contract coverage. Request counts do not cap provider
  billing, so provider-side spending limits remain required.
- **External data processing — REQUIRES USER CONSENT:** optional AI or URL
  reputation analysis can send minimized scan data or the submitted URL to
  selected third parties. Provider retention, plan availability, and pricing
  were not independently verified. `urlscan.io` may retain submitted URLs
  according to provider policy.
- **Local notification data — PARTIALLY IMPLEMENTED:** the opt-in Android
  notification listener stores notification text and package metadata in
  app-private SharedPreferences. Application-layer encryption and a tested
  retention policy are not implemented.
- **Android/OEM crash — NOT TESTED:** no redacted Huawei HarmonyOS crash log
  was supplied, so the launch failure's root cause is unknown.
- **Platform identity — REQUIRES MANUAL ACTION:** iOS bundle ID
  `com.example.cyvoraMobile` differs from Android
  `com.example.cyvora_mobile`. Do not change either identity until the owner
  confirms the intended App Store identity. Xcode build, signing, provisioning,
  privacy declarations, and a release build need a macOS/Xcode environment.

## Safe handling and validation

- Never put production keys, signing passwords, or private credentials in
  source, `.env.example`, logs, issues, or chat. Use the secure Supabase
  Dashboard/CLI secret configuration.
- Do not expose the Supabase service-role key to Flutter or ordinary users.
- Do not deploy migrations, change production secrets/settings, or release a
  signed build without separate approval and a reviewed deployment plan.
- The latest pushed baseline is `a6e01c8`; the current AI cooldown,
  deduplication, concurrency, and verified-threat skip changes are uncommitted.
  The latest recorded CI run for the pushed baseline passed, and the current
  local test run passed 86 backend tests plus Flutter analysis and 59 Flutter
  tests. These results do not replace database, provider, or device testing.
- Until the atomic invitation-quota migration is applied to the intended
  environment together with the updated Edge Function, the deployed version
  retains the prior race condition.
- Run backend unit tests and Flutter tests without production credentials.
  Validate RLS and family account isolation against an isolated database with
  multiple test accounts.
- Review redacted device logs before sharing them; remove tokens, notification
  content, addresses, email addresses, and other personal data.

See [the verified audit](CYVORA_PRODUCTION_AUDIT.md) and
[the production readiness report](CYVORA_PRODUCTION_READINESS.md) for
evidence, test results, and remaining blockers.
