# Cyvora AI Integration Test Report

## Pipeline status

**NOT VERIFIED LIVE.** The implemented pipeline is:

Flutter -> DashboardPresenter/Repository -> `scam-intelligence` Edge Function
-> server validation/quota/provider adapters -> response -> Flutter.

| Test | Expected | Actual | Status |
|---|---|---|---|
| Edge request body limit | 64 KiB/valid JSON | Source/tests passed | PASS |
| Input validation | Message/URL/screenshot recognized | Tests/source passed | PASS |
| AI response schema | Invalid output rejected | Synthetic tests passed | PASS |
| Risk 0–100 | Scores remain bounded | Synthetic tests passed | PASS |
| Safe/suspicious/malicious/inconclusive | Distinct results | Synthetic tests passed | PASS |
| AI fail closed | No fake safe result on provider failure | Synthetic tests passed | PASS |
| Timeout/fallback | Useful error state | Synthetic tests passed | PASS |
| Duplicate notification scan | Replay completed result | Tests passed | PASS |
| 10/10 window | Atomic 10-minute reservation | Static migration/test passed | PASS |
| 50 cloud daily limit | Default/explicit budgets enforced | Migration/source test passed | NOT TESTED LIVE |
| Ollama routing | Local model unavailable behavior | Ollama is excluded from source routing | NOT TESTED |
| Live Edge provider call | Real provider response | No credentials/deployment | BLOCKED |
| Web local Ollama | Graceful unavailable state | Ollama explicitly unsupported | BLOCKED |
