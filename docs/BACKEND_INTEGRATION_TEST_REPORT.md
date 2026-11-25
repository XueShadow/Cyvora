# Cyvora Backend Integration Test Report

| Test | Expected | Actual | Status |
|---|---|---|---|
| Supabase CLI status | Local stack status | CLI unavailable | BLOCKED |
| Docker daemon | Supabase containers available | Docker Desktop daemon unavailable | BLOCKED |
| Migration list | Hosted ledger compared | No Supabase access | BLOCKED |
| DB lint | Migration lint passes | No CLI/Postgres | BLOCKED |
| RLS cross-account | Private rows isolated | Migration/source tests only | NOT TESTED |
| Scan history retention | 30/60/90 setting enforced | Migration/UI static pass; live Cron blocked | NOT TESTED |
| Family authorization | Owners/members limited | Source tests pass; live database blocked | NOT TESTED |
| Edge authentication | JWT and manual identity required | Config/source tests pass | PASS |
| Edge request validation | Invalid/oversized bodies rejected | 106-node suite passes | PASS |
| Service-role isolation | Secret only server-side | Source scan found no embedded secret | PASS |
| Atomic quotas | Concurrent requests cannot bypass | Migration/source tests pass; live concurrency blocked | NOT TESTED |
| Account deletion | Auth/data/avatar removal | Source/action tests pass; live blocked | BLOCKED |
