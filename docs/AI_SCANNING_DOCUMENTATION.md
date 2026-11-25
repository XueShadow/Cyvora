# Cyvora AI Scanning Documentation

The `scam-intelligence` function combines local rules, reviewed local/community
indicators, network/TLS checks, optional URL reputation, and optionally selected
AI providers. Provider output is validated and does not override the unified
classification automatically.

## Failures

AI/provider failure is distinct from an inconclusive or safe result.
Unavailable providers must not produce a successful safe classification.

## Quotas

- Cloud AI: atomic 10-per-10-minute request window.
- Daily cloud budget: provider/global/user limits, default 50.
- Existing 30-per-day scan/rate tables remain server-enforced.

## Minimization

Provider requests use bounded, redacted content and normalized findings.
Provider credentials remain server-side. Provider DPA, live model, retention,
cost, and outage behavior are externally unverified.
