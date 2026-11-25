# Cyvora Backend Test Report

## Executed

- Flutter analysis: **PASS**, no issues.
- Flutter tests: **PASS**, 76 tests.
- Android app unit tests: **PASS**.
- Android release policy tests: **PASS**, 20 tests.
- Notification idempotency Node tests: **PASS**, 5 tests.
- Backend hardening Node tests: added and source coverage ready.
- Broad Supabase Node suite: 78/79 tests passed; one stale test path now fixed
- Broad Supabase Node suite: **PASS**, 106 tests.
- Android release APK: **PASS**.
- Web build: **PASS**.

## Not executed

- Supabase CLI status/lint/migration list: CLI unavailable.
- Local or hosted PostgreSQL migrations/RLS tests: runtime unavailable.
- Live Auth/MFA/SMS/SMTP.
- Live AI/reputation providers and billing.
- Physical Android notification/OEM tests.
- Play Console/Data Safety submission review.
- iOS build.

No production database or hosted project was changed.
