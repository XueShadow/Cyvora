# Cyvora

Cyvora is a Flutter mobile app with Supabase authentication, scam analysis, and
family security features.

## Repository layout

- [`flutter/`](flutter/) - Flutter application and app-specific setup guide.
- [`supabase/`](supabase/) - Supabase migrations and Edge Functions.
- [`laravel/`](laravel/) - Laravel project.
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
The three guardrail migrations are present in the public repository (through
commit `0313782`); that does not establish that they were applied to a local,
staging, or production database. PostgreSQL execution and live provider tests
remain unverified.
The current local backend suite passes 89 tests, and Flutter analysis plus 59
widget tests pass. These local checks do not execute the migrations against
PostgreSQL or prove deployed RPC/function behavior.
The push/PR checks are defined in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml). Read the
[production readiness report](docs/CYVORA_PRODUCTION_READINESS.md),
[security notes](docs/SECURITY.md), and
[verified audit results](docs/CYVORA_PRODUCTION_AUDIT.md) before release.

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
