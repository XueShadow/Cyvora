# Cyvora Synthetic Scam-Detection Evaluation

## Result

The focused regression test passed:

```powershell
node --test .\supabase\tests\scam-evaluation.test.mjs
```

The fixture contains 26 hand-authored synthetic examples: 13 labeled scam and
13 labeled legitimate.

| Metric | Result |
|---|---:|
| True positives | 13 |
| False positives | 0 |
| True negatives | 13 |
| False negatives | 0 |
| Precision | 1.00 |
| Recall / sensitivity | 1.00 |
| Specificity | 1.00 |
| F1 | 1.00 |
| Accuracy | 1.00 |

Each added category contains one positive and one benign example:

| Category | Examples | TP | FP | TN | FN |
|---|---:|---:|---:|---:|---:|
| Bank / OTP | 2 | 1 | 0 | 1 | 0 |
| Government impersonation | 2 | 1 | 0 | 1 | 0 |
| Delivery fee | 2 | 1 | 0 | 1 | 0 |
| Romance / secrecy / money | 2 | 1 | 0 | 1 | 0 |
| Brand lookalike | 2 | 1 | 0 | 1 | 0 |
| Unicode homograph | 2 | 1 | 0 | 1 | 0 |

The original 14 examples remain as baseline coverage. The six category pairs
exercise bank/OTP requests, government impersonation, delivery fees, romance
scams, brand lookalikes, and Unicode/punycode URLs. Test URLs use reserved
`.example` names for suspicious destinations and static benign URL examples;
no URLs were resolved or fetched, and no provider or external target was
contacted.

## Interpretation and limitations

These are synthetic regression cases selected to exercise known deterministic
rules (`bantai-rules-1`), not a random sample. The perfect scores are expected
fixture behavior, not evidence of real-world precision, recall, F1, or false
positive rate. The category pairs are too small for statistical conclusions,
and no held-out split, independent adjudication, prevalence weighting, or
drift analysis exists. The fixture does not establish detection performance
across Filipino/Taglish variants, dialects, campaigns, new brands, or
adversarial rewrites.

No live AI provider or URL intelligence service was called. This evaluation
does not validate their authentication, billing, timeout, outage, quota, or
deployment behavior.

## Recommended evaluation before release

1. Build a consented, minimized, moderator-reviewed corpus in Filipino,
   Taglish, and English with legitimate and scam examples across categories.
2. Keep a held-out, time-separated set that is not used to tune rules.
3. Use at least two independent reviewers and resolve disagreements before
   calculating metrics.
4. Report confusion counts, precision, recall, F1, false-positive rate, and
   per-category results with denominators and confidence intervals.
5. Test benign lookalikes, official-domain messages, Unicode domains, short
   messages, and long messages explicitly.
6. Define release thresholds based on product risk and user impact; do not
   use this fixture's 1.00 scores as a release threshold.

The source fixture is
[`supabase/tests/scam-evaluation.test.mjs`](../supabase/tests/scam-evaluation.test.mjs).
