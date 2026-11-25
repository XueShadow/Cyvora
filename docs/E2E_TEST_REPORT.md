# Cyvora End-to-End Test Report

## Overall

**NOT VERIFIED END-TO-END.** Source unit/build coverage passes, but hosted
Supabase, live credentials, provider connectivity, Android hardware, and local
Ollama execution are unavailable.

| Area | Status | Evidence |
|---|---|---|
| Flutter dependencies | PASS | `flutter pub get` succeeded |
| Flutter analysis | PASS | No issues |
| Flutter tests | PASS | 76 tests passed |
| Android debug APK | PASS | `app-debug.apk` built |
| Web build | PASS | `build/web` built |
| Hosted Supabase | BLOCKED | Supabase CLI unavailable; no credentials |
| Live Auth/MFA/reset | BLOCKED | Requires hosted project and test account |
| Live Edge Functions | BLOCKED | Docker daemon and Supabase CLI unavailable |
| Live AI/Ollama | BLOCKED | Ollama not implemented/routed; no credentials |
| Android runtime | BLOCKED | No physical/emulator device |
| Web live auth/session | BLOCKED | Port 8765 no live HTTP server at probe time |

## Execution sequence

1. Inspected MVP, backend, migrations, Edge Functions and UI.
2. Restored Flutter dependencies.
3. Ran analysis and tests.
4. Built Android debug APK and Web.
5. Checked Docker, Supabase, ADB/device availability.
6. Checked source secrets and `.env` tracking.
7. Ran 106 Supabase Node static/synthetic tests.
