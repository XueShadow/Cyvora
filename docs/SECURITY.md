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
  limits, a provider circuit breaker, user cooldowns, HMAC-based duplicate
  suppression, and provider concurrency leases. It stops fallback after
  circuit-open or HTTP 429 responses and skips optional AI when verified threat
  intelligence is sufficient. Migration deployment and PostgreSQL execution
  are unverified. Migration 004 defers dedupe writes until quota reservation
  succeeds, and the provider adapter now preserves scan reservation IDs for
  completion accounting. Request counts do not limit dollar spend.
- Startup diagnostics log fixed phase labels and an exception type, not the
  exception message, token, URL, or user content.
- Android notification previews are collected only after explicit local
  consent and Android notification-listener access. The queue uses AES/GCM
  encryption backed by Android Keystore, migrates existing plaintext queue
  entries when read, defaults to seven-day expiry, supports 1/7/30-day
  retention, and can be cleared by the user. The Android manifest disables
  backup. A queued notification is removed only after analysis succeeds.
- Android release workflow source validates stable tags against the default
  branch, isolates build/sign/publish jobs with least-privilege permissions,
  and gates signing/publishing on named GitHub Environments. Publishing
  creates a draft release for owner review.

The Supabase production migration ledger was inspected on 2026-11-17 and
showed `202611150005_mfa_enforcement` as its latest entry. Migrations
`202611150006` and `202611170001`–`202611170004` were not recorded. No SQL was
executed, and deployed Edge Function revisions remain unverified.

## Confirmed residual risks and unverified controls

- **Invitation rate-limit race — FIX IMPLEMENTED, DEPLOYMENT REQUIRED:** a new
  migration adds a per-family transaction advisory lock around the quota check
  and insert; the Edge Function now uses that RPC. The migration is absent
  from the observed production ledger, and no live concurrent-request test was
  available.
- **MFA enrollment — PARTIALLY IMPLEMENTED:** AAL2 is required for users who
  have a verified factor, but enrollment is not mandatory for all accounts.
- **Family isolation — NOT TESTED:** ownership and RLS were inspected, but
  separate-user integration tests against a local or staging database were
  unavailable.
- **Provider spend and resilience — PARTIALLY IMPLEMENTED:** pushed migrations
  002–004 and the Edge Function integration implement request-count budgets,
  cooldown/deduplication/concurrency controls, and a circuit breaker. Database
  deployment and SQL concurrency behavior are unverified; migration 004
  carries the forward dedupe-order correction. Request counts do not cap provider
  billing, so provider-side spending limits remain required.
- **External data processing — REQUIRES USER CONSENT:** optional AI or URL
  reputation analysis can send minimized scan data or the submitted URL to
  selected third parties. Provider retention, plan availability, and pricing
  were not independently verified. `urlscan.io` may retain submitted URLs
  according to provider policy.
- **Local notification data — IMPLEMENTED IN SOURCE; DEVICE BEHAVIOR NOT
  VERIFIED:** previews are encrypted in app-private storage with a
  non-exportable Android Keystore key. Existing plaintext queue entries are
  migrated on read. If the Keystore key becomes unavailable, preview access
  fails rather than falling back to plaintext. Retention and deletion controls
  are implemented, but exact expiry timing across force-stop/reboot, key-loss
  recovery, OEM lifecycle behavior, and permission revocation have not been
  tested on devices. Disabling consent stops new collection but does not
  automatically erase queued previews; the user can delete them separately.
- **Notification content redaction — NOT IMPLEMENTED:** notifications are
  manually selected before analysis and optional AI processing is separately
  selected. The selected text is not currently redacted locally for names,
  phone numbers, account identifiers, or OTP values before the analysis
  request. Users should avoid scanning messages containing credentials or
  one-time codes until redaction is implemented.
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
- The repository contains migrations 001–004 and their Edge Function
  integration. The production dashboard ledger ends at `202611150005`;
  migrations `202611150006` and `202611170001`–`202611170004` are not recorded
  as applied. The local Node suite passes 89 tests and Flutter tests pass 64;
  these do not replace database, provider, or device testing.
- Until the atomic invitation-quota migration is applied to the intended
  environment together with the matching Edge Function, the quota protection
  is not verified in production.
- Run backend unit tests and Flutter tests without production credentials.
  Validate RLS and family account isolation against an isolated database with
  multiple test accounts.
- `supabase/tests/security_boundaries.test.sql` prepares pgTAP checks for
  scan RLS, family isolation, foreign-account writes, unauthorized RPC
  execution, expired invitations, and AI quota reservation/exhaustion. Run it
  only with the local Supabase test database (`supabase test db`); it was not
  executed here because Supabase CLI, PostgreSQL, and Docker were unavailable.
  Existing Node tests statically check migration contracts but cannot prove
  database concurrency or deployed policy behavior.
- Android release Environments named `android-signing` and `android-publish`
  must be created with required reviewers. Move signing secrets into
  `android-signing`, restrict stable `v*` tag creation/updates, and require
  reviewed changes on the default branch. These GitHub settings were not
  changed or verified. The owner must review and publish draft releases.
- Review redacted device logs before sharing them; remove tokens, notification
  content, addresses, email addresses, and other personal data.

See [the verified audit](CYVORA_PRODUCTION_AUDIT.md),
[the latest security review](CYVORA_SECURITY_AUDIT.md), and
[the production readiness report](CYVORA_PRODUCTION_READINESS.md) for evidence,
test results, and remaining blockers.
