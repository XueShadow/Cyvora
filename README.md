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
Optional AI remains disabled unless explicitly selected; enabling it also
requires server-side daily request limits. These limits are not billing caps.
See [`supabase/PROVIDER_STATUS.md`](supabase/PROVIDER_STATUS.md) before enabling
an external provider or applying the corresponding database migration.
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
