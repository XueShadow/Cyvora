# Cyvora architecture map

> **Current status update:** The architecture below describes the earlier
> audit baseline. Android notification previews now use encrypted,
> consent-controlled local storage with retention/deletion controls, and
> notification scan requests carry a server idempotency key on the current
> remediation branch. All 24 repository migrations through `202611170007`
> were applied to a fresh disposable Supabase PostgreSQL database and the
> three latest migrations reapplied successfully. Hosted deployment state
> and physical-device behavior remain unverified. See the
> [current complete security audit](CYVORA_COMPLETE_SECURITY_AUDIT.md).

**Audit date:** 2026-11-17
**Repository baseline:** `c8aab7970b30216a6477f6bd61486ce9d71c7a22`
**Scope:** Read-only architecture inspection; no application code or production
configuration was changed.

## System map

```text
Flutter mobile client
  ├─ Supabase Auth and MFA
  ├─ Dashboard screens and scan-history UI
  ├─ DashboardRepository (Supabase queries and Edge Function calls)
  ├─ On-device screenshot OCR
  └─ Android notification listener bridge
       └─ native listener queue -> explicit in-app review -> scan request

Supabase Edge Functions
  ├─ scam-intelligence
  │    ├─ deterministic scam-pattern and indicator analysis
  │    ├─ DNS/TLS and optional URL-reputation checks
  │    ├─ optional AI provider routing
  │    ├─ scan persistence and assistant chat
  │    └─ reviewed intelligence submission/release operations
  └─ family-invitations
       ├─ invite, revoke, accept
       └─ service-role database operations after bearer-token/MFA checks

Supabase PostgreSQL
  ├─ application data and Row Level Security policies
  ├─ ownership/family authorization helpers
  ├─ invitation and scan RPCs
  └─ versioned migrations

Laravel 13
  └─ standalone framework scaffold; default public welcome route

GitHub Actions
  ├─ CI: Flutter dependency check, analysis, widget tests, Android debug APK
  │      and Supabase Node tests
  └─ Android release: tag/manual workflow, signing-secret validation,
         signed APK/AAB validation and GitHub Release publication
```

## Component responsibilities and boundaries

### Flutter

`flutter/lib/main.dart` initializes Supabase when both URL and publishable key
are configured. `AuthGate` observes Supabase Auth state, applies the client MFA
step-up gate, and passes the signed-in identity to the dashboard. The
`DashboardRepository` interface separates dashboard widgets from
`SupabaseDashboardRepository`, which reads user-scoped records and invokes the
two Edge Functions. `dashboard_screen.dart` contains the home, scan, history,
family, alerts, and profile flows. Screenshot text extraction is on-device;
the screenshot itself is not sent by the current analysis path.

### Supabase Edge Functions and database

`scam-intelligence` is the central server analysis entry point. Deterministic
analysis remains the baseline; AI and external URL reputation are optional.
The function validates request sizes, coordinates modules, persists scan
results, and uses server-side provider configuration. `family-invitations`
handles invitation operations using the service-role key only server-side.

Migrations define schemas, RLS, RPCs, quotas, provider health, and retention.
All 24 repository migrations through `202611170007` were applied locally
using direct `psql` against a disposable Supabase PostgreSQL 17.11.0.018
container, then migrations `202611170005`–`202611170007` were reapplied.
Catalog checks found RLS enabled on all 31 public tables and no public
`SECURITY DEFINER` functions lacking a fixed `search_path`. This does not
establish hosted or production migration state; no current hosted ledger or
deployed Edge Function revision was checked.

### Android and iOS

Android uses a native `NotificationListenerService`, not the default-SMS-app
role. It queues eligible notification title/text/package metadata in
app-private AES/GCM-encrypted storage backed by Android Keystore, with
1/7/30-day retention and clear controls. Flutter exposes a user-initiated
review list; the selected item is sent to the server only after the user
chooses to scan it. This is not automatic background analysis. No per-app
exclusion setting or per-notification content-length cap was found. iOS uses
the Flutter app and
Supabase Auth callback URL scheme; no equivalent notification-listener
implementation was identified.

Configured identities differ: Android namespace/application ID
`com.example.cyvora_mobile`; iOS bundle ID `com.example.cyvoraMobile`.
Both retain `com.example` identifiers. They were not changed because
production identity must be confirmed by the owner first. iOS build and
signing were not tested on this Windows host.

### Laravel

`laravel/` is a Laravel 13 scaffold with a default root welcome route and
example tests. No Cyvora API contract or Flutter/Supabase integration was
identified. Its intended role needs an owner decision; this audit does not
remove or replace it.

## Assessment

- The existing Flutter + Supabase architecture is coherent for the current
  client and server-side analysis flows; a rewrite is not indicated.
- `DashboardRepository` is a useful data boundary, but
  `dashboard_screen.dart` and `dashboard_repository.dart` carry many unrelated
  features and are large. Incremental feature-level extraction could improve
  maintainability after the higher-priority deployment and verification gaps
  are resolved.
- Laravel has no documented production responsibility yet.
- CI validates local/client code and mocked/static backend behavior. It does
  not run PostgreSQL migrations, RLS integration tests, deployed Edge Function
  tests, live provider calls, iOS builds, or device notification tests.
- Production readiness is not established. See
  [the full audit](CYVORA_FULL_CODE_AUDIT.md),
  [security audit](CYVORA_SECURITY_AUDIT.md), and
  [test results](CYVORA_TEST_RESULTS.md).
