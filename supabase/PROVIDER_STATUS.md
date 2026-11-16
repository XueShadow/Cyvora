# Cyvora provider and capability status

Status reflects repository code and local tests as of 2026-11-17. Provider
credentials remain in Supabase and are not read or printed during this audit.
A previously recorded user-provided scan showed requests reaching eight AI
providers, but none returned validated analysis. No new live provider calls
were made.

User-approved privacy scope for this implementation: keep screenshot processing
to on-device OCR text, use reviewed indicators and hashes only for intelligence,
and keep Ollama excluded.

## AI text providers

| Provider | Status | Adapter / capability | Test and limitation |
|---|---|---|---|
| Google Gemini | ATTEMPTED; no validated response in latest scan | Text analysis through chat completions | Model-specific availability and structured output are unverified. |
| Groq | ATTEMPTED; no validated response in latest scan | Text analysis through chat completions | Model-specific availability and structured output are unverified. |
| OpenRouter | ATTEMPTED; invalid response in latest scan | Text analysis through chat completions | Free-model routing and response formats vary. |
| Mistral AI | NOT CONFIGURED | Text analysis through chat completions | Mocked only; model capability is not discovered dynamically. |
| Cloudflare Workers AI | ATTEMPTED; model reported retired in latest scan | Text analysis through account-scoped chat endpoint | Account, token, model, and quota are not independently verified. |
| SambaNova Cloud | ATTEMPTED; billing required in latest scan | Text analysis through chat completions | Account billing/plan must permit inference. |
| Cohere | ATTEMPTED; timed out in latest scan | Text analysis through compatibility endpoint | Live model support and network availability are unverified. |
| NVIDIA NIM | ATTEMPTED; model reported retired in latest scan | Text analysis through chat completions | Account and model availability are not independently verified. |
| Z.AI / GLM | NOT CONFIGURED | Text analysis through chat completions | Mocked only; live model support is unverified. |
| Hugging Face Inference Providers | ATTEMPTED; request rejected in latest scan | Text chat-completions adapter | Provider/model availability and structured-output support are unverified. |
| Ollama | DISABLED | Excluded from code and configuration per user request | Do not configure or deploy Ollama. |

AI routing now requires an explicit `AI_PROVIDER_ORDER`, an API key, and a
provider-selected model ID. It calls at most the selected primary and one
optional fallback; API keys alone do not activate providers. The fallback can
be disabled with `AI_FALLBACK_ENABLED=false`, and per-provider disable flags
remain available. Calls use bounded timeouts and validated JSON output. Valid
summaries are retained when optional fields differ from the expected format;
unrecognized signal labels and malformed actions are discarded. There is no
provider dollar-spend budget. New server-side controls reserve daily request
counts atomically across global, per-user, and per-provider limits. All three
limits must be configured as positive integers (maximum 100,000) or AI calls
fail closed as unavailable/not configured. Per-provider settings use
`AI_<PROVIDER>_DAILY_REQUEST_LIMIT`, for example
`AI_GEMINI_DAILY_REQUEST_LIMIT`. Request counts are not currency caps; configure
provider-side spending limits separately.
Provider attempts now record duration and status; the
`provider_health_daily` view aggregates recent AI and URL provider outcomes.
The new `ai_provider_health` view reports daily AI request counts, latest
status/latency, and circuit state. Both views are restricted to `service_role`
and are not an administrator UI or a live credential test. After three
consecutive provider failures, the new circuit breaker opens for 15 minutes;
only one half-open probe is allowed for 90 seconds after cooldown. Accounting
failures stop fallback routing. Fallback can send minimized scan data to more
than one provider.
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
| Server-side enforcement | DEPLOYED | `202611150005_mfa_enforcement.sql` requires AAL2 for users with verified MFA factors, and the protected Edge Functions reject incomplete MFA sessions. |
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
| Provider quotas, usage history, budgets, circuit breakers | IMPLEMENTED LOCALLY; DEPLOYMENT REQUIRED | Atomic global, per-user, and per-provider daily request limits plus a three-failure/15-minute circuit breaker are in `202611170002_ai_provider_guardrails.sql`. Missing/invalid limits fail closed. The status/usage view and RPC are service-role-only. The migration is not deployed or live-tested. These counts do not cap provider dollar spend. |
| Flutter scan, history, reports, family features | PARTIALLY COMPLETED | Existing user flows call the centralized backend; admin provider controls and push/background monitoring are absent. |

## Database, deployment, and verification

Database migrations contain scan evidence, reviewed indicators, feedback, and
ownership protections. The local-only
`202611140001_operational_metrics.sql` migration adds service-role-only daily
provider health/latency and detection-feedback evaluation views. They do not
provide an administrator UI or provider dollar billing data. The local-only
`202611170002_ai_provider_guardrails.sql` migration adds request-count budgets,
a provider circuit breaker, and service-role-only health state. Neither it nor
the atomic family invitation quota migration is independently verified as
deployed. Embedding and model-evaluation tables are not implemented.
DNS-over-HTTPS, provider diagnostics, updated model
defaults, the Cohere endpoint, and the response-normalizing parser are deployed.
The latest evidence-linked explanation and prevention-guidance improvements are
local and require an approved Edge Function deployment and Flutter release.
Local tests use mocked providers; they do not prove a live integration,
free-tier eligibility, licensing compliance, or provider availability.

The local Node suite covers request construction, response validation, fallback
and primary-only routing, URL privacy-target filtering, risk handling, and
provider failure states. Flutter analysis, widget tests, and web release build
are run separately. A live provider test requires user-managed credentials in
Supabase Edge Function Secrets and an approved staging environment; never paste
credentials into chat or commit them.
