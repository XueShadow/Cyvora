# Cyvora Android Test Report

| Test | Expected | Actual | Status |
|---|---|---|---|
| Debug APK build | APK generated | `app-debug.apk` generated | PASS |
| Release APK build | Release artifact generated | Prior/recent build evidence passed | PASS |
| Package/permission dump | Minimal permission set | Internet/signature permission only | PASS |
| Restricted permissions | No SMS/call/location/storage/camera | None found | PASS |
| Notification listener disclosure | Opt-in and separate consent | Source implemented | PASS |
| Listener denial/revoke | Monitoring stops and UI reloads | No Android device | BLOCKED |
| Screenshot selection | System photo picker works | Build/source only | NOT TESTED |
| Authentication/scanning | Real flows work | No account/device | BLOCKED |
| Runtime crash/log check | No crashes | No device available | BLOCKED |
| Permission revocation | Accurate status, queued data removed | No device | BLOCKED |
| iOS | iOS build/runtime | No macOS/Xcode | NOT TESTED |
