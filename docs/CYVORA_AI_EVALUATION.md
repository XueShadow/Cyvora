# Cyvora AI and Scam-Detection Evaluation

## Synthetic evaluation

The Supabase Node suite ran 26 labeled synthetic examples:

- True positives: 13
- True negatives: 13
- False positives: 0
- False negatives: 0
- Precision: 1.00
- Recall: 1.00
- F1: 1.00
- False-positive rate: 0.00
- False-negative rate: 0.00

## Limitations

This is a deterministic source-level regression fixture, not production-grade
accuracy evidence. It does not represent a representative, independently
separated Filipino/Taglish real-world corpus. It also does not measure
deceptive obfuscation, unseen brands, evolving campaigns, or human adjudication.

## Verified controls

- AI calls require configured and authorized provider budgets.
- AI output cannot change the base scan classification.
- Provider failures are reported separately from the scam verdict.
- Provider credentials remain server-side.
- URL and safety-assistant context is redacted before external provider use.
- Database/DNS outages remain UNKNOWN rather than clean.
- Optional AI is disabled when no provider key is configured.

## Remaining validation

Build an independently labeled, held-out English/Filipino/Taglish corpus and
test provider outage, timeout, rate-limit, billing, fallback, false-positive,
and false-negative behavior against staging providers.
