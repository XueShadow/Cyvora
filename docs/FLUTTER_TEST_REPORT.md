# Cyvora Flutter Test Report

| Test | Expected | Actual | Status |
|---|---|---|---|
| `flutter pub get` | Dependencies resolve | Resolved successfully | PASS |
| `flutter analyze` | No analyzer findings | No issues | PASS |
| `flutter test` | 76 tests pass | 76 passed | PASS |
| Splash tests | Animation and transition complete | Passed | PASS |
| Responsive layout tests | Compact/wide layouts remain valid | Passed | PASS |
| Auth widget tests | Validation and reset/dialog flows work | Passed | PASS |
| Dashboard widget tests | Navigation and state remain valid | Passed | PASS |
| Scanner tests | Local and server result states work | Passed | PASS |
| Family tests | Views and mutations remain bounded | Passed | PASS |
| Notification queue tests | Retry, retention, consent, cleanup | Passed | PASS |
| Permission Presenter tests | Allowlist and platform states enforce | Passed | PASS |
| Android debug build | APK generated | `app-debug.apk` generated | PASS |
| Web build | Web artifact generated | `build/web` generated | PASS |
| Real Supabase UI integration | Hosted account actions succeed | Not executed | BLOCKED |
| Screenshot platform behavior | Picker/OCR works on device | Source/build only | NOT TESTED |
