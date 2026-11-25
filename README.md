# Cyvora

Cyvora is a Flutter mobile app with Supabase authentication, scam analysis, and
family security features.

## Repository layout

- [`flutter/`](flutter/) - Flutter application and app-specific setup guide.
- [`supabase/`](supabase/) - Supabase migrations and Edge Functions.
- [`laravel/`](laravel/) - Official Cyvora Super Admin panel with separate
  authentication, MFA, role-based authorization, and administrative workflows.
  See the [Super Admin guide](docs/CYVORA_SUPER_ADMIN_GUIDE.md) and
  [architecture map](docs/CYVORA_ARCHITECTURE.md).
- [`docs/`](docs/) - Production readiness, audit, and security reports.

## Run the app

Install Flutter, then run these commands from the repository root:

```powershell
cd flutter
flutter pub get --enforce-lockfile
flutter run
```

Supabase configuration, backend setup, testing, and release safety are in
[`flutter/README.md`](flutter/README.md) and [`supabase/README.md`](supabase/README.md).
Optional AI remains disabled unless explicitly selected. Enabling it requires
server-side global, per-user, and per-provider daily request limits; the
follow-up migration also adds duplicate suppression, user cooldowns, and
provider concurrency limits. Request-count limits are not billing caps, and
the migrations/functions must be deployed to the intended environment before
those controls take effect. See
[`supabase/PROVIDER_STATUS.md`](supabase/PROVIDER_STATUS.md) before enabling an
external provider or applying a migration. No live provider result or Supabase
deployment is verified by local tests.
The Supabase migration-ledger observation recorded in earlier audit notes is
historical, not a current deployment check. No production migration or
function deployment was performed for this update. Repository migrations and
local tests do not prove which schema or Edge Function revisions are
deployed; validate them in an isolated staging project before production.

The latest recorded local checks are in
[`docs/TESTING_AND_VALIDATION.md`](docs/TESTING_AND_VALIDATION.md). The latest
security-branch reports describe direct PostgreSQL migration and pgTAP checks
on a disposable Supabase database image; those checks were not rerun during
this integration because the Docker daemon is unavailable. Current integration
test results are recorded in [`docs/CYVORA_TEST_RESULTS.md`](docs/CYVORA_TEST_RESULTS.md).
They do not verify live provider behavior, hosted staging/production state,
or current GitHub settings.

## Architecture

The Flutter app is organized incrementally around MVP boundaries: application
setup and dependency injection live in `flutter/lib/app/`, shared services and
UI foundations in `flutter/lib/core/`, backend adapters in
`flutter/lib/data/`, and feature code in `flutter/lib/features/`. Authentication
and dashboard operations use Presenters and repository contracts; some
dashboard subviews and state remain co-located pending further extraction.
See the [Flutter architecture guide](flutter/ARCHITECTURE.md) for the current
structure and migration notes.

## Validation and deployment status

GitHub Actions runs Flutter dependency validation, analysis, tests, an Android
debug APK build, a Web build, and the Supabase Node test suite on pushes and
pull requests. The latest recorded local validation passed Flutter analysis,
76 Flutter tests, the Android debug APK and Web builds, 106 Supabase Node
tests, and 28 Laravel tests (125 assertions). These are local/source-level
checks; they do not establish live Supabase, provider, or device behavior.

CI builds artifacts but does not deploy the Web app, Supabase migrations, or
Edge Functions. Android release automation creates a draft release and depends
on owner-configured protected GitHub Environments; it does not automatically
publish releases. No production deployment is claimed. See
[`docs/DEPLOYMENT_STATUS.md`](docs/DEPLOYMENT_STATUS.md) and the
[end-to-end test report](docs/E2E_TEST_REPORT.md) for current limits and
unverified integrations.

The push/PR checks are defined in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml). Read the
[production readiness report](docs/CYVORA_PRODUCTION_READINESS.md),
[full code audit](docs/CYVORA_FULL_CODE_AUDIT.md),
[security audit](docs/CYVORA_SECURITY_AUDIT.md),
[architecture map](docs/CYVORA_ARCHITECTURE.md),
[test results](docs/CYVORA_TEST_RESULTS.md), and
[security notes](docs/SECURITY.md) before release. Current remediation
evidence is in the [complete security audit](docs/CYVORA_COMPLETE_SECURITY_AUDIT.md),
[remediation report](docs/CYVORA_REMEDIATION_REPORT.md),
[staging validation plan](docs/CYVORA_STAGING_VALIDATION.md), and
[final production checklist](docs/CYVORA_FINAL_PRODUCTION_CHECKLIST.md).

## Download an Android release

The GitHub Actions workflow builds a signed Android APK for direct installation
and an Android App Bundle (AAB) for Google Play. Releases are published on the
[GitHub Releases page](https://github.com/XueShadow/Cyvora/releases).

To publish a release:

1. Configure the protected GitHub Environments `android-signing` and
   `android-publish`. Put `ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
   `KEY_ALIAS`, and `KEY_PASSWORD` only in `android-signing` Environment
   secrets, never ordinary repository or organization secrets. Require owner
   approval for signing and publishing, and restrict deployments to the
   protected default branch and stable `v*` release tags.
2. Update the app version in [`flutter/pubspec.yaml`](flutter/pubspec.yaml).
3. Push a version tag, for example:

   ```powershell
   git tag v1.0.2
   git push origin v1.0.2
   ```

The workflow validates the tag and its commit against the default branch,
builds the validated commit, and creates a draft release. An owner must review
the signed artifacts/checksums and publish the draft manually. Manual
dispatches are subject to the same tag and branch validation. GitHub
Environment reviewers, deployment restrictions, and `v*` tag rulesets require
manual owner configuration; the workflow's use of Environment names does not
prove that their protection rules are configured. See the [release security
guide](docs/RELEASE_SECURITY_GUIDE.md) and
[`flutter/README.md`](flutter/README.md).
