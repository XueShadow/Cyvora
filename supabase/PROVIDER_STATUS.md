# Cyvora provider and capability status

Status reflects repository code and local tests as of 2026-11-17. Provider
credentials and runtime model settings were not read. No live provider calls
were made. Outcomes noted as previously reported are unverified and were not
reproduced during this review.

User-approved privacy scope for this implementation: keep screenshot processing
to on-device OCR text, use reviewed indicators and hashes only for intelligence,
and keep Ollama excluded.

## AI text providers

| Provider | Configured model | Configuration status | Last verified test status | Failure reason, if any | Required action |
|---|---|---|---|---|---|
| Google Gemini | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan had no validated response; not reproduced | In approved staging, verify selected model, authentication, and structured response; set a provider request limit. |
| Groq | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan had no validated response; not reproduced | In approved staging, verify selected model, authentication, and structured response; set a provider request limit. |
| OpenRouter | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan reported an invalid response; not reproduced | Verify current model route and response format in staging; set a provider request limit. |
| Mistral AI | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan said not configured; not independently checked | Configure only if selected; verify the model and structured response in staging. |
| Cloudflare Workers AI | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan reported a retired model; not reproduced | Choose a currently supported account model and verify in staging. |
| SambaNova Cloud | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan reported billing required; not reproduced | Confirm account billing and model access before enabling. |
| Cohere | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan timed out; not reproduced | Verify endpoint/model and bounded response time in staging. |
| NVIDIA NIM | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan reported a retired model; not reproduced | Choose a currently supported model and verify in staging. |
| Z.AI / GLM | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan said not configured; not independently checked | Configure only if selected; verify authentication and structured output in staging. |
| Hugging Face Inference Providers | Not disclosed; runtime secrets not inspected | UNKNOWN | Mocked adapter behavior only; live response NOT TESTED | Prior user-reported scan reported a rejected request; not reproduced | Verify provider/model access and response format in staging. |
| Ollama | Not applicable | DISABLED by requirement | NOT TESTED; excluded from routing | Not applicable | Keep disabled and do not add local-model dependencies. |

AI routing now requires an explicit `AI_PROVIDER_ORDER`, an API key, and a
provider-selected model ID. It calls at most the selected primary and one
optional fallback; API keys alone do not activate providers. The fallback can
be disabled with `AI_FALLBACK_ENABLED=false`, and per-provider disable flags
remain available. Calls use bounded timeouts and validated JSON output. Valid
summaries are retained when optional fields differ from the expected format;
unrecognized signal labels and malformed actions are discarded. There is no
provider dollar-spend budget. Server-side controls reserve daily request counts atomically across global,
per-user, and per-provider limits. All three limits must be configured as
positive integers (maximum 100,000) or AI calls fail closed as
unavailable/not configured. The cooldown/deduplication/concurrency controls in migration 003 are present
in the repository; deployment is unverified. Migration 004 carries the
dedupe-order correction while preserving migration 003's published contents.
The scan reservation-ID fix is in the provider adapter. The backend mock
suite passes 94 tests; this is not a PostgreSQL or live-provider test.
Per-provider settings use
`AI_<PROVIDER>_DAILY_REQUEST_LIMIT`, for example
`AI_GEMINI_DAILY_REQUEST_LIMIT`. Request counts are not currency caps; configure
provider-side spending limits separately.
If unset, the server-side cooldown, duplicate window, and concurrency settings
default to 10 seconds, 300 seconds, and 10 active requests per provider,
respectively; they can be overridden within migration 003's validated bounds.
Repository migrations record provider duration and status and define the
`provider_health_daily` view for AI and URL provider outcomes. The local
migrations define the `ai_provider_health` view with daily AI request counts,
latest status/latency, and circuit state. Both views are restricted to
`service_role`; deployment is unverified, and neither view is an administrator
UI or a live credential test. The circuit breaker
opens after three consecutive provider failures for 15 minutes; only one
half-open probe is allowed for 90 seconds after cooldown. Accounting failures,
an open circuit, and provider HTTP 429 responses stop fallback routing, so a
failed or quota-limited primary does not consume another provider's quota.
Deterministic analysis also skips optional AI when verified threat intelligence
already establishes a malicious result. Other fallback calls may still send
minimized scan data to a second selected provider.
HTTP 402, 404, and 410 responses now identify billing, missing-model/endpoint,
and retired-model failures separately. There are no code-default model IDs;
configure each selected provider's `*_MODEL` value only after reviewing its
current model catalog. Compatibility, plan availability, and pricing still
require independent verification.

## URL intelligence

| Provider | Status | Adapter / behavior | Test and limitation |
|---|---|---|---|
| URLhaus | NOT CONFIGURED | URL lookup | Mocked response only. |
| Google Safe Browsing | NOT CONFIGURED | URL lookup | Mocked response only; intended for eligible non-commercial use. |
| AlienVault OTX | NOT CONFIGURED | URL indicator lookup | Mocked response only. |
| OpenPhish | PARTIALLY COMPLETED | Public community feed cached and checked locally | Mocked feed; live feed freshness and access were not verified. |
| PhishTank | NOT CONFIGURED | URL lookup | Mocked response only. |
| urlscan.io | NOT CONFIGURED | Private URL scan submission | Mocked submission only; privacy setting is requested but retention is controlled by the provider. |
| ThreatFox | NOT CONFIGURED | Exact URL indicator lookup | Mocked response only. |
| VirusTotal | NOT CONFIGURED | URL lookup | Mocked response only. |
| Pulsedive | NOT CONFIGURED | Documented indicator lookup; high/critical risk is a match, lower ratings are unverified | Mocked response only; never actively probes submitted targets. |

External checks are opt-in per URL scan and skip private/reserved destinations.
Provider matches can raise the result to `SUSPICIOUS`, not independently to
`MALICIOUS`. The OpenPhish feed is cached in memory; persistent result caching,
deduplication, scheduled synchronization, domain-wide correlation, and live
provider health checks are not implemented.

DNS analysis uses Cloudflare DNS-over-HTTPS. Plain HTTP URLs are flagged as
unencrypted even when DNS returns no address. HTTPS TLS handshakes run only
after DNS resolves to a public IP; the submitted page and redirects are not
fetched.

## Screenshots and OCR

| Capability | Status | Details |
|---|---|---|
| On-device mobile OCR | PARTIALLY COMPLETED | ML Kit Latin OCR runs on Android/iOS; extracted text can be submitted to the centralized scan endpoint after scan/AI consent. |
| Web OCR | IMPLEMENTED LOCALLY | Tesseract.js runs in a browser worker. The engine and English model download on first use; screenshot bytes stay in the browser and are never uploaded. |
| Image upload and validation | NOT IMPLEMENTED | Screenshot bytes are not sent to Supabase or external AI providers. |
| Vision-model adapters | NOT IMPLEMENTED | No Gemini, Groq, OpenRouter, Mistral, Cloudflare, Cohere, SambaNova, NVIDIA, Z.AI, or Hugging Face image adapter is active. |

## SMS multi-factor authentication

| Capability | Status | Details |
|---|---|---|
| Phone MFA enrollment and verification | IMPLEMENTED; provider pending | Flutter uses Supabase Phone MFA enrollment, challenge, and verify APIs. Phone numbers are validated as E.164 values. |
| Sign-in step-up challenge | IMPLEMENTED; provider pending | Verified phone factors require an AAL2 challenge before the dashboard is shown. |
| Resend and expiration handling | IMPLEMENTED | The UI blocks resends for 30 seconds, honors the challenge expiration returned by Supabase, and displays rate-limit, expiration, and network errors. |
| Server-side enforcement | IMPLEMENTED IN REPOSITORY; DEPLOYMENT UNVERIFIED | `202611150005_mfa_enforcement.sql` requires AAL2 for users with verified MFA factors, and the protected Edge Functions reject incomplete MFA sessions. |
| SMS delivery | NOT VERIFIED | A real provider must be configured and a real delivery/verification test must pass before this is considered operational. |

### Configure SMS delivery manually

1. Open **Supabase Dashboard > Authentication > Providers > Phone** for the
   linked Cyvora project.
2. Select a supported SMS provider (Twilio, Vonage, or MessageBird), or use a
   custom **Send SMS Hook**.
3. Enter the provider credentials only in the Supabase Dashboard secure
   configuration. Do not add them to Flutter, Edge Function source, `.env`
   files committed to the repository, or chat.
4. Enable phone MFA enrollment and verification. Keep OTP verification enabled.
5. Review the Auth rate limits and set provider-appropriate limits for SMS
   sends, verification attempts, and per-phone/IP abuse protection.
6. Create a test account, enroll a phone using an E.164 number such as
   `+14155552671`, verify the received code, sign out, sign in again, and
   verify the step-up code.
7. Test an incorrect code, an expired code, resend after the cooldown, a
   provider/network failure, and a rate-limited response. Do not call the
   feature operational until delivery and verification succeed.

## Adaptive learning and operations

| Capability | Status | Details |
|---|---|---|
| Versioned heuristic rules | PARTIALLY COMPLETED | Rule configuration and local scam-pattern detection exist. |
| Reviewed community indicators | PARTIALLY COMPLETED | User reports remain pending review; reviewed hashes can inform scans. |
| Similarity, embeddings, campaign grouping, drift evaluation, model training | NOT IMPLEMENTED | `detection_feedback_daily` provides service-role-only, aggregate feedback counts for evaluation. Feedback and reports do not automatically train or update a model. |
| Unified analysis endpoint and risk scoring | PARTIALLY COMPLETED | Authenticated `scam-intelligence` coordinates local rules, DNS/TLS, reviewed indicators, optional AI, optional URL reputation, and saved results. |
| Provider registry | PARTIALLY COMPLETED | Server-side configuration metadata includes model, text-analysis capability, and configured/disabled status; it is not an administrator dashboard or live health check. |
| Provider quotas, usage history, budgets, circuit breakers | IMPLEMENTED IN REPOSITORY; DEPLOYMENT UNVERIFIED | Atomic global, per-user, and per-provider daily request limits plus a three-failure/15-minute circuit breaker are in `202611170002_ai_provider_guardrails.sql`. Missing/invalid limits fail closed. The status/usage view and RPC are service-role-only. No deployment or live behavior was verified. These counts do not cap provider dollar spend. |
| Flutter scan, history, reports, family features | PARTIALLY COMPLETED | Existing user flows call the centralized backend; admin provider controls and push/background monitoring are absent. |

## Database, deployment, and verification

An earlier dashboard inspection, dated 2026-11-17, observed
`202611150005_mfa_enforcement` as the latest recorded production migration.
That observation is historical and was not rechecked during the current
workspace review. Migrations `202611150006` and `202611170001`–`202611170005`
are present in the repository; their current deployment status is UNVERIFIED.
No SQL was executed and deployed Edge Function revisions were not checked.
Validate pending migrations in timestamp order in isolated staging before any
production deployment.

Migrations 001–005 and the corresponding Edge Function RPC integration are in
the repository. PostgreSQL execution, Edge Function runtime tests, and live
provider behavior are NOT TESTED. Migration 004 is a forward correction to
deduplication ordering; migration 005 adds notification-scan idempotency and
must be applied before deploying a client that sends notification idempotency
keys.

Database migrations in the repository contain scan evidence, reviewed
indicators, feedback, and ownership protections. The
`202611140001_operational_metrics.sql` migration adds service-role-only daily
provider health/latency and detection-feedback evaluation views. They do not
provide an administrator UI or provider dollar billing data. The
`202611170002_ai_provider_guardrails.sql` migration adds request-count budgets,
a provider circuit breaker, and service-role-only health state. Neither it nor
the atomic family invitation quota migration is independently verified as
deployed. Embedding and model-evaluation tables are not implemented.
DNS-over-HTTPS, provider diagnostics, model-selection support, the Cohere
endpoint, and the response-normalizing parser are present in repository code;
deployment status is unverified. Evidence-linked explanations and
prevention-guidance code are also present, but app/function rollout was not
verified.
Local tests use mocked providers; they do not prove a live integration,
free-tier eligibility, licensing compliance, or provider availability.

The local Node suite covers request construction, response validation, fallback
and primary-only routing, URL privacy-target filtering, risk handling,
reservation completion IDs, provider failure states, and static migration
contracts. The current local full-suite result is 94 passed; PostgreSQL
execution and provider behavior remain NOT TESTED. Flutter analysis and 66
widget tests also passed locally. A live provider test requires user-managed credentials in
Supabase Edge Function Secrets and an approved staging environment; never paste
credentials into chat or commit them.
