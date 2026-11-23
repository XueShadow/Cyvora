# Cyvora

Cyvora is a Flutter mobile app with Supabase authentication, scam analysis, and
family security features.

## Repository layout

- [`flutter/`](flutter/) - Flutter application and app-specific setup guide.
- [`supabase/`](supabase/) - Supabase migrations and Edge Functions.
- [`laravel/`](laravel/) - Intended Cyvora Super Admin panel. The current
  Laravel code is still scaffold-only; see the
  [architecture and readiness reports](docs/CYVORA_ARCHITECTURE.md).
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
The Supabase production migration ledger was inspected on 2026-11-17 and
showed `202611150005_mfa_enforcement` as its latest entry. Repository
migrations `202611150006` and `202611170001`–`202611170004` were not recorded
as applied. No SQL was executed during the audit. Validate the pending
migrations in isolated staging before production; repository presence does not
prove that Edge Functions are deployed.

The local baseline passed Flutter analysis, 59 Flutter tests, 89 Supabase
backend tests, and an Android debug APK build. GitHub Actions run
[44035823882](https://github.com/XueShadow/Cyvora/actions/runs/44035823882)
passed for commit `c8aab797`. These checks do not execute migrations against
PostgreSQL or verify live provider behavior.
The push/PR checks are defined in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml). Read the
[production readiness report](docs/CYVORA_PRODUCTION_READINESS.md),
[full code audit](docs/CYVORA_FULL_CODE_AUDIT.md),
[security audit](docs/CYVORA_SECURITY_AUDIT.md),
[architecture map](docs/CYVORA_ARCHITECTURE.md),
[test results](docs/CYVORA_TEST_RESULTS.md), and
[security notes](docs/SECURITY.md) before release.

## Download an Android release

The GitHub Actions workflow builds a signed Android APK for direct installation
and an Android App Bundle (AAB) for Google Play. Releases are published on the
[GitHub Releases page](https://github.com/XueShadow/Cyvora/releases).

To publish a release:

1. Configure the repository secrets `ANDROID_KEYSTORE_BASE64`,
   `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD`. See the keystore
   instructions in [`flutter/README.md`](flutter/README.md).
2. Update the app version in [`flutter/pubspec.yaml`](flutter/pubspec.yaml).
3. Push a version tag, for example:

   ```powershell
   git tag v1.0.2
   git push origin v1.0.2
   ```

The workflow builds both release packages and attaches them to the GitHub
Release for that tag. It can also be started manually from the Actions tab with
a release tag.
