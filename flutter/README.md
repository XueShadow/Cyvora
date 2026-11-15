# Cyvora Mobile

Flutter client for Cyvora, with Supabase authentication, scam analysis, and
family security features on iOS, Android, and web.

## Configure Supabase

1. The Cyvora project URL and publishable key are configured as app defaults.
   You can override them with `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
   A legacy anon key is also accepted.
2. Enable **Confirm email** for Email under **Authentication → Sign In /
   Providers**. New email/password accounts must follow the confirmation link
   delivered to their mailbox before they can sign in.
3. Configure a custom SMTP provider in the project's Auth SMTP settings. The
   Supabase default email service is restricted and rate-limited; for reliable
   delivery, use a verified sender with an email provider. Check the provider's
   delivery logs and the recipient's spam folder when messages are missing.
4. For password reset and signup confirmation, allow the mobile callback
   `io.supabase.cyvora://login-callback/` and the local/deployed web origin in
   **Authentication → URL Configuration → Redirect URLs**.
5. Run the app with your project values:

   ```powershell
   flutter run `
     --web-port=3000 `
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co `
     --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY
   ```

The public/anon key is intended for client apps. Never put a Supabase
`service_role` key in a mobile application. Protect database tables with
Row-Level Security (RLS) and policies.

The app has the Cyvora project's public URL and publishable key as defaults.
If overriding them, provide both values; supplying only one is a startup error.
Account creation collects a first and last name along with email and password.
The names are saved as `first_name` and `last_name` in the Supabase Auth user's
metadata. The app rejects missing names and malformed email addresses before
submitting signup. Signup also requires acceptance of the in-app Terms of
Service and acknowledgment of the in-app Privacy Policy; the acceptance
timestamp and version labels are saved in Auth user metadata. The Terms of
Service version is `v2`; the Privacy Policy version is `v12`. The policies
identify Ji Monsales and
jimonsales71@gmail.com, and specify the Philippines as the governing
jurisdiction, subject to mandatory legal protections. They are informational
product terms and do not constitute legal advice.

Signup passwords must be at least 12 characters and contain at least three of
these four types: uppercase, lowercase, number, and one of Supabase's supported
symbols. The strength indicator and signup validator use the same rule. Login
continues to use its existing validation.
Supabase Auth's project-wide minimum length is set to 12 characters. This may
affect existing accounts with shorter passwords. Supabase's built-in character
requirements cannot express “any three of four” exactly, so the category rule
is enforced by this app's signup form, not by direct calls to the Auth API.
Email verification depends on **Confirm email** remaining enabled in Supabase;
this is required to verify that the user can access the submitted mailbox.
After signup, the app displays a confirmation screen with the address to
check, a resend option, and a button to return to login. The app can request an
email resend, but actual delivery depends on the Supabase SMTP configuration
and the email provider's delivery status.
After a user opens the confirmation link, Supabase redirects to the app's web
origin or mobile callback. The auth gate automatically opens the Cyvora
dashboard when Supabase returns a valid session. Keep the Supabase **Confirm
sign up** email template's action link set to `{{ .ConfirmationURL }}` and
include the app origin in **Authentication → URL Configuration → Redirect URLs**.

## GitHub release deployment

The repository-level GitHub Actions workflow at
[`../.github/workflows/android-release.yml`](../.github/workflows/android-release.yml)
builds a signed Android APK for direct installation and an Android App Bundle
for Google Play, then attaches both files to a GitHub Release.

Before the workflow can run, add these repository secrets in GitHub:

- `ANDROID_KEYSTORE_BASE64`: Base64-encoded contents of the Android release keystore.
- `KEYSTORE_PASSWORD`: Keystore password.
- `KEY_ALIAS`: Key alias used for the release signing key.
- `KEY_PASSWORD`: Password for the release key alias.

From the `flutter` directory, create a keystore locally. Keep a secure backup
of this file and store both passwords in a password manager; Android updates
must continue using the same signing key.

```powershell
keytool -genkeypair -v `
  -keystore .\android\app\release-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias cyvora-release
```

Keytool prompts for the keystore password, key password, and certificate details.
To copy the encoded keystore without printing it in the terminal:

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes('.\android\app\release-keystore.jks')
) | Set-Clipboard
```

In the repository's **Settings → Secrets and variables → Actions**, create
`ANDROID_KEYSTORE_BASE64` by pasting the clipboard value, `KEYSTORE_PASSWORD`
and `KEY_PASSWORD` with the passwords you chose, and `KEY_ALIAS` with
`cyvora-release`. The workflow writes `android/key.properties` automatically;
never commit the keystore or its passwords.

Update the app version in `pubspec.yaml`, then trigger a release by pushing a
tag such as `v1.0.2`, or run the workflow manually with a tag name. Use the
signed APK from the GitHub Release for direct installation and the AAB for
Google Play. Debug APKs are for development and are signed with a debug key;
do not distribute them. Local release APK/AAB builds require a valid
`android/key.properties` and release keystore.

Play Protect may still warn about a sideloaded app, especially one that offers
notification scanning. A production signature does not establish Play Protect
reputation by itself. For testing on devices, use a Google Play internal testing
track when possible; keep Play Protect enabled and install only builds from a
source you trust.

## Dashboard integrations

The signed-in dashboard provides Home, History, Family, Alerts, and Profile
tabs. Message, URL, and screenshot scans and scam reports are available from
Home's Quick Tools.
Apply the Supabase migration and deploy the invitation function before using
these data-backed features:

```powershell
npx.cmd --yes supabase login
npx.cmd --yes supabase link --project-ref wohfevsfhzgxejcfcrek
npx.cmd --yes supabase db push
npx.cmd --yes supabase functions deploy family-invitations `
  --project-ref wohfevsfhzgxejcfcrek
```

The login command requires a Supabase personal access token; enter it only in
the terminal prompt, never in chat or source code. Family invitations use a
shareable code only and do not send email or require an email-provider secret.
The owner enters the invited person's Cyvora account email and shares the
generated code with them out of band. The invite is accepted only by a signed-in
account with that verified email address. The function is configured with
gateway JWT verification disabled so browsers can send CORS preflight requests;
it validates the bearer token against Supabase Auth before every action. It
also checks the family-owner role, limits invitations to five per family per
hour, and creates a one-time code that expires after seven days.

The database migration adds Row-Level Security policies for scan metadata,
family groups, opt-in shared reports, scam reports, profiles, and in-app
alerts. Each account can belong to one family group at a time. Owners can
invite/remove members, change sharing, or delete their group; members can
leave. Family report sharing can be turned off, which hides shared reports
from the group. The migration also enables Realtime for alerts when the
project's `supabase_realtime` publication is available.

The `202611120001_user_privacy_settings.sql` migration adds per-user privacy
and notification preferences. Sharing and push-notification preferences
default to off, and each user can read or update only their own settings. The
database creates a settings row when an account is created and backfills
existing accounts. Users can review these preferences in Profile. The app
stores them as a secure backend foundation; sharing protection status, scan
results, family alerts, and push delivery are not activated by these settings.
Any future feature that uses them must check the corresponding preference
before sharing or sending notifications.

The History tab retrieves the signed-in user's saved records in newest-first
pages of 50. Search applies to the records currently loaded and matches scan
type, risk label, summaries, warning indicators, recommendations, evidence, and
confidence reasons; load older records to search further back. Opening a record
shows its saved classification, rule and optional AI findings, supporting
evidence, module results and statuses, confidence reasons, prevention steps,
analysis engine version, and analysis timestamp. Scan times are shown in the
device's local time zone. The app does not retain the original message, URL, or
screenshot text.

### Independent server-side analysis

Message, URL, and screenshot-text scans use the authenticated
`scam-intelligence` Edge Function. Flutter performs OCR only; the server
calculates the verdict and confidence. Analysis uses configurable
English/Filipino/Taglish scam rules, URL structure and redirect-parameter
checks, public DNS-over-HTTPS and TLS validation, and exact matches against reviewed
local/community indicator hashes by default. It does not fetch
submitted pages or follow redirects. DNS/TLS checks can connect to a validated
public address, and private/reserved destinations are blocked. Hostname DNS
queries use Cloudflare's public DNS-over-HTTPS resolver.

The verdict is `SAFE`, `SUSPICIOUS`, `MALICIOUS`, or `UNKNOWN`. Only reviewed
exact local indicators or at least three distinct reviewed community reporters
can confirm a malicious result. Unreviewed submissions are not detections.
Unavailable or incomplete checks are shown as such and cannot count as clean.
`UNKNOWN` means evidence was insufficient; even `SAFE` is not a guarantee.
Scan metadata and normalized module evidence are saved, not the original
message, URL, or screenshot text.

Users may explicitly opt into AI-provider-assisted analysis for an individual
scan. The server sends minimized content and normalized findings to the first
configured provider that responds, trying configured providers in this order:
Google Gemini, Groq, OpenRouter, Mistral AI, Cloudflare Workers AI, SambaNova
Cloud, Cohere, NVIDIA NIM, Z.AI, and Hugging Face Inference Providers. Email
addresses, phone numbers, numeric codes, URL query values, and fragments are
redacted where applicable. The
backend validates the structured response; AI output can add context but
cannot independently declare a URL safe or override verified threat evidence.

Provider keys are issued by each provider and must be kept in Supabase Edge
Function secrets; never put them in the Flutter app or source control. Add a
key only for providers you have enabled and reviewed for pricing, free-tier
limits, data processing, and retention. An API key does not guarantee free
usage. Each configured provider may receive minimized scan content during
fallback, so use the per-scan AI option only when that transfer is acceptable.

Configure the provider keys in the Supabase Dashboard under **Edge Functions
→ Secrets**, or set them with the Supabase CLI. Recognized secret names:
See [`supabase/.env.example`](../supabase/.env.example) for a blank template and
[`supabase/PROVIDER_STATUS.md`](../supabase/PROVIDER_STATUS.md) for verified
implementation boundaries. Never commit actual keys.

```text
GEMINI_API_KEY
GROQ_API_KEY
OPENROUTER_API_KEY
MISTRAL_API_KEY
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
SAMBANOVA_API_KEY
COHERE_API_KEY
NVIDIA_API_KEY
ZAI_API_KEY
HF_TOKEN
```

Optional model overrides are `GEMINI_MODEL`, `GROQ_MODEL`, `OPENROUTER_MODEL`,
`MISTRAL_MODEL`, `CLOUDFLARE_MODEL`, `SAMBANOVA_MODEL`, `COHERE_MODEL`,
`NVIDIA_MODEL`, `ZAI_MODEL`, and `HUGGINGFACE_MODEL`. `AI_PROVIDER_ORDER` can
override the default comma-separated order using the IDs
`gemini,groq,openrouter,mistral,cloudflare,sambanova,cohere,nvidia,zai,huggingface`.
Set `AI_FALLBACK_ENABLED=false` to use only the first configured provider.
Providers can be disabled independently with `AI_PROVIDER_<ID>_ENABLED=false`,
where `<ID>` is the uppercase provider ID (for example,
`AI_PROVIDER_GEMINI_ENABLED=false`).
Cloudflare Workers AI also requires the account ID. Providers without a key
(or, for Cloudflare, an account ID) are skipped. The backend tries providers
sequentially with bounded timeouts and reports the provider that succeeded.
The internal registry reports only provider IDs, model names, text-analysis
capability, and configured/disabled status; it never includes API secrets. This
is configuration metadata, not a live health check or model-capability
discovery.
When an opted-in provider call fails, results include only a safe failure
category and HTTP status code when available—not provider response bodies or
credentials.

### Optional URL reputation checks

For URL scans only, users may separately opt in to query all configured URL
reputation sources. Cyvora aggregates their results in parallel and records
each provider's status. The submitted URL is sent without its fragment to
configured providers; query values are included, so do not scan links that
contain private tokens unless you accept sharing them. Private and reserved
destinations are not sent to these providers. The OpenPhish community feed is
downloaded and checked locally; the URL itself is not sent to OpenPhish.

Configure only the services you intend to use as Supabase Edge Function
secrets:

```text
URLHAUS_AUTH_KEY
GOOGLE_SAFE_BROWSING_API_KEY
OTX_API_KEY
PHISHTANK_API_KEY
URLSCAN_API_KEY
THREATFOX_AUTH_KEY
VIRUSTOTAL_API_KEY
PULSEDIVE_API_KEY
```

OpenPhish uses its public community feed and does not require a key. Provider
checks without a configured key are skipped. Google Safe Browsing is configured
for eligible non-commercial use only. urlscan.io receives a **private**
submission; the private scan may still be retained under urlscan.io's terms,
and results may take longer than the Cyvora request to finish. A returned
private scan ID is saved with the scan result. Provider terms, rate limits,
retention, and free-tier eligibility vary.
Pulsedive uses its documented indicator lookup API. High or critical risk
ratings count as a match; lower/unknown ratings are shown as unverified, not
as evidence that a URL is safe. The provider API key is sent only to Pulsedive.

A provider match changes the classification to `SUSPICIOUS`, but external
matches alone never produce `MALICIOUS`; the existing reviewed local/community
threshold remains in effect. A clean or unavailable provider result does not
prove that a URL is safe. Without a per-scan opt-in, no external URL reputation
provider is queried.

Scam report descriptions are stored in Supabase and are shared with family
only when the author explicitly opts in and family sharing is enabled. Users
may also submit an optional URL/domain indicator. Cyvora stores only its
normalized hash and category in a pending-review record; a raw URL is never
stored in the community indicator table. Review submissions before adding
them to the curated local indicator database.

### Server-side analysis details

The Supabase Edge Function validates the signed-in user, enforces a 30-scan
daily limit per account, loads versioned rule configuration, performs
server-side rule, URL, DNS/TLS, and local indicator analysis, and returns one
validated assessment.
The rules recognize English, Filipino, and Taglish urgency, credential
requests, payment patterns, claimed brands, lookalike domains, shorteners,
encoded hosts, and explicit redirect parameters. Redirect destinations are
inspected only as text. No destination URL is fetched or followed.

The authenticated API is `POST /functions/v1/scam-intelligence` with
`{"type":"message","input":"...","use_ai":true}`; `type` can also be `url` or
`screenshot`. Omit `use_ai` or set it to `false` to skip external AI-provider
analysis. URL scans may additionally set `"use_url_reputation":true` after
the user explicitly consents; this queries all configured reputation sources.
A successful response contains `scan_id`, `classification` (`SAFE`,
`SUSPICIOUS`, `MALICIOUS`, or `UNKNOWN`), `risk_level` (`LOW`, `MEDIUM`,
`HIGH`, `CRITICAL`, or `UNDETERMINED`), integer confidence from 0 to 100,
`confidence_reasons`, `analysis_summary`, `indicators`, `rule_analysis`,
`analysis_modules`, `analysis_modules_status`, `ai_analysis`, bounded
`evidence`, `recommended_actions`, `analyzed_at`, and `engine_version`.
Each internal module result includes its status, evidence kind, confidence,
source, timestamp, and any unavailable/error reason.

The rule-based scan endpoint works without AI-provider keys. AI assistance is
optional and requires at least one configured provider secret. Removing this
integration from code does not automatically remove obsolete secrets from a
hosted Supabase project.

Detection rules are versioned and their enabled state and weights are stored
in `scam_patterns`. Community reports remain pending until reviewed, and only
distinct reviewed reporters are counted. The curated local indicator database
is service-role-only. Module evidence, analysis status, confidence reasons,
and results are attached to the saved scan under RLS. Deleting a scan also
deletes its module evidence.

Apply the independent-analysis and URL-reputation migrations before deploying
the updated function:

```powershell
npx.cmd --yes supabase db push
npx.cmd --yes supabase functions deploy scam-intelligence `
  --project-ref wohfevsfhzgxejcfcrek
```

`202611130003_independent_analysis.sql` adds analysis-module evidence, reviewed
local/community indicator tables, self-only report visibility, updates the
scan RPC, and retires provider cache/quota records. Earlier migrations are
kept as immutable history. The existing scam-intelligence quota migration
`202611120004_scam_intelligence_quota.sql` must also be applied.
`202611130004_url_reputation.sql` adds the optional external reputation module
to persisted analysis results.

The Flutter client receives the backend's saved scan ID and does not create a
duplicate `scan_records` row. Message, URL, and screenshot-text checks display
classification, confidence, evidence, internal module status, recommendations,
and timestamps.

The Node analysis tests can be run from the project root:

```powershell
node --experimental-strip-types --test supabase/tests/*.test.mjs
```

For Flutter, run `flutter analyze` and `flutter test` from `flutter\`. To
validate database access controls, apply the migration to a local Supabase
stack and test with separate authenticated user sessions; the service-only
write RPC and self-only select policies are defined in the migration.

These checks can miss scams or flag legitimate content. A low-risk result is
not proof that an item is safe. Optional third-party AI analysis is generated
by external providers and may be wrong. In-app alerts are generated for high-risk saved scans and scam
reports; push notifications are not configured. The app does not provide
continuous/background device monitoring, block messages or links, verify
threat intelligence, or monitor emergencies. Do not rely on Cyvora for
emergency warnings or as a substitute for independent verification.

If a migration or function deployment has not been applied, the dashboard
shows the backend error rather than pretending that data was saved. Users can
delete saved scan history from Profile; account deletion requests are handled
through the Privacy Policy contact details.

## Run checks

```powershell
flutter analyze
flutter test
```
