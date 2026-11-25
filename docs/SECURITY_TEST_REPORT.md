# Cyvora Security Test Report

| Test | Expected | Actual | Status |
|---|---|---|---|
| Service-role key in Flutter | No private key | No embedded private key pattern found | PASS |
| Secrets committed | No real secret files | Real `.env` files were not in `git ls-files` | PASS |
| RLS on sensitive tables | Tables restricted | Migration source uses RLS and grants | NOT TESTED LIVE |
| Cross-account scan isolation | Users cannot read others' scans | Migration policy source only | NOT TESTED |
| Edge JWT verification | Gateway verifies bearer token | `verify_jwt = true` for both functions | PASS |
| Edge manual auth | `auth.getUser` identity used | Source present | PASS |
| OTP/password collection | Not collected unnecessarily | Notification filter/source UI only | PASS |
| Notification consent | Explicit opt-in/revoke | Source implementation present | NOT TESTED DEVICE |
| Private logs | No complete private messages | Source test/sanitized logging only | PASS |
| Account deletion | Auth and related data removed | Source/Edge implementation | NOT TESTED LIVE |
| Restricted Android permissions | Not declared | Final APK dump minimal | PASS |
| Google Play approval | Policy review passed | Not submitted/reviewed | NOT TESTED |
