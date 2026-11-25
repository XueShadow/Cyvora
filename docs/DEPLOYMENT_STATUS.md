# Cyvora Deployment Status

## Repository deployment automation

- **Continuous integration:** `.github/workflows/ci.yml`
  - Flutter dependencies, analysis, tests, Android debug APK, and Web build.
- **Android releases:** `.github/workflows/android-release.yml`
  - Stable tag validation, signed APK/AAB staging, draft GitHub release.
  - Requires owner-managed `android-signing` and `android-publish` environments.
- **Supabase migrations/functions:** no production or staging deployment workflow.
- **Web hosting:** no hosting provider or deployment workflow is configured.
- **Ollama:** intentionally excluded from provider routing.

## Deployment rules

Do not deploy Supabase migrations or Edge Functions automatically. Review,
apply, and record migrations in isolated staging first. Do not publish an
Android draft or release without artifact validation and owner approval.

No production Supabase migration, Edge Function deployment, GitHub Pages
deployment, web-host deployment, Play publishing, or live Ollama deployment
was performed in this environment.
