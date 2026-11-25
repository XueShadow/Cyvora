# Cyvora Android Permission Audit

## Audit date

Source audit: 2026-11-26.

## Scope

The audit covered Android manifests, Gradle configuration, Flutter dependencies,
native Kotlin sources, runtime permission calls, notification-listener
components, image pickers, and the merged debug manifest produced after a clean
Flutter build.

## Original inventory

| Permission / access | Purpose | Feature | Mandatory | Restriction | Decision |
|---|---|---|---|---|---|
| `INTERNET` | Supabase, scan APIs, URL checks, AI providers | App networking | Yes | Normal | Retain |
| `ACCESS_NETWORK_STATE` | Network-state API support | No verified feature logic used it | No | Normal | Remove |
| `POST_NOTIFICATIONS` | Not used for implemented push delivery | None | No | Runtime on Android 13+ | Remove |
| Notification Listener special access | Optional notification-monitoring review queue | User-selected messaging notifications | No | Sensitive/special access | Retain opt-in only |
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Bind the declared listener service | Notification listener | No | Signature/system-bound | Retain |
| Third-party `ACCESS_NETWORK_STATE` | Added by Google Data Transport/AndroidX merge | No verified feature logic | No | Normal | Remove via manifest merge rule |

## Permissions not found

No SMS, MMS, Call Log, Contacts, location, camera, media-library,
external-storage, accessibility, package-visibility, all-files, or foreground-service
permission was found in the source manifest or the merged debug manifest.

The image-picker plugin declares no broad storage requirement for the implemented
Android photo-picker flow. It uses a system picker/file provider and temporary
selected URIs.

## Third-party manifest contributions

The merged debug manifest included:

- AndroidX/Flutter dynamic-receiver signature permission.
- ImagePicker file-provider and Google Play services photo-picker metadata.
- ML Kit text-recognition components.
- Supabase/Flutter and AndroidX startup components.

These did not add a broad storage, SMS, Call Log, location, camera, contacts,
foreground-service, accessibility, or notification runtime permission.

## Final inventory

| Permission / access | Final status |
|---|---|
| `INTERNET` | Retained for backend and network features |
| `ACCESS_NETWORK_STATE` | Removed |
| App signature receiver permission | AndroidX dynamic receivers; signature-level, not user-granted | Retained/automatic |
| `POST_NOTIFICATIONS` | Removed; no app-owned push delivery is implemented |
| SMS / Call Log / Contacts / Location / Camera / Media / Storage | Removed/not declared |
| Notification Listener access | Optional, special-access, user-controlled |

## Implemented native changes

- Removed `ACCESS_NETWORK_STATE`.
- Removed `POST_NOTIFICATIONS`.
- Removed `permission_handler` from Flutter dependencies.
- Added a centralized permission Presenter and Android repository.
- Added a supported-app allowlist.
- Added consent-gated, app-filtered notification capture.
- Added title/body limits and a sensitive-content filter for OTP, login,
  verification, password, passcode, PIN, and numeric-only code previews.
- Added pending-preview deletion on consent revocation or app deselection.
- Added Android lifecycle refresh after notification-listener settings.
- Added release-validator rejection for restricted and unnecessary permissions.
- Removed third-party `ACCESS_NETWORK_STATE` merge contribution with a manifest
  merge rule.

## Verification

- `flutter clean` and `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: 73 tests passed.
- Android `:app:testDebugUnitTest`: passed.
- Android release APK build: passed.
- Final release APK permission dump: `INTERNET` plus the app's signature-level
  dynamic-receiver permission only.
- Android-aapt final merged release manifest: no SMS, Call Log, location,
  contacts, camera, media, storage, foreground, accessibility, or notification
  runtime permission.
- No physical Android/OEM device was available, so runtime listener/revocation
  behavior remains unverified.

## Hardening limits

The sensitive-content filter is heuristic and cannot guarantee detection of every
authentication secret. User-selected app package filtering is enforced inside
the native queue, so unrelated packages are not stored.

No notification-listener behavior was certified on physical Android/OEM devices
by this source audit.
