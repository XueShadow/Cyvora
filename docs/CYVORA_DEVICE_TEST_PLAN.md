# Cyvora Android Physical-Device Test Plan

## Status and scope

**Execution status: NOT RUN.** No physical Android device was available;
`adb` was unavailable and the listed emulator was offline. No emulator result
is presented as physical-device evidence.

The plan validates the opt-in Android notification listener and its encrypted,
user-reviewed queue. The app does not replace the default SMS application and
does not automatically submit notifications for analysis.

## Test prerequisites

- Use a non-production build and test account with synthetic messages only.
- Record the build commit, app version, package ID, device manufacturer/model,
  Android version/API level, security patch date, and build fingerprint.
- Prefer one physical device on a currently supported Android release and one
  additional OEM device. The release validator currently requires `minSdk`
  24 and `targetSdk` at least 35; include an API 24 device if available.
- Do not use real financial, authentication, health, or personal notifications.
- Do not put notification text, access tokens, or provider inputs in test
  notes, screenshots, bug reports, or logs.

## Test cases

| ID | Test | Expected result |
|---|---|---|
| DEV-01 | Install, open settings, grant notification-listener access, and accept monitoring consent. | Access and consent are explicit; the default SMS application is unchanged. |
| DEV-02 | Deny listener access or leave monitoring consent off, then post a synthetic notification. | No preview is queued or submitted. |
| DEV-03 | Post the same synthetic notification from two controlled test apps, then post an update to one notification. | Both sources are attributed correctly; updates replace/suppress the prior queue entry rather than creating duplicate scans. |
| DEV-04 | Select a queued item and force an offline/server failure; restore connectivity and retry. | The item remains available after failure; the user can retry; successful replay creates one scan result. |
| DEV-05 | Kill/restart the app before analysis, during analysis, after server success, and before local cleanup. | The queue recovers without losing an unfinished item or producing duplicate server history. |
| DEV-06 | Inspect app-private preferences while queued content exists and exercise queue read/write. | Stored preview data is AES/GCM encrypted; no plaintext title/body is persisted in preferences. Never export the ciphertext or content. |
| DEV-07 | Test each 1-, 7-, and 30-day retention setting using a controlled test clock or disposable test data. | Expired items are removed and the next expiry is scheduled; changing retention does not affect unrelated data. |
| DEV-08 | Revoke notification-listener access and separately revoke monitoring consent. | Capture stops immediately; consent revocation clears queued previews as described in the UI. |
| DEV-09 | Simulate Android Keystore key loss or app data restore without the original key. | Decryption failure is surfaced safely, no plaintext fallback occurs, and the recovery path does not silently report success. |
| DEV-10 | Reboot, force-stop, enter Doze/App Standby, enable OEM battery optimization, and restrict background network. | Queue retention and scheduled expiry remain correct; scans occur only through the intended user-reviewed flow. |
| DEV-11 | Post very long title/body values and multiple notifications in quick succession. | Record the actual platform and storage behavior. The current source has no per-notification content-length bound; define and verify a user-visible policy before calling this case passed. |
| DEV-12 | Inspect app/system logs while posting, scanning, failing, and retrying synthetic messages. | No notification content, tokens, or provider request data is logged. |

## Evidence record

For each case, record only:

- Test ID and PASS/FAIL/BLOCKED.
- Device/build metadata listed above.
- App permission/consent state and queue item counts.
- Sanitized error class, HTTP status, and scan-row count where relevant.
- Whether a retry succeeded and whether duplicate records were observed.

Do not retain message text or credentials in the evidence record. Mark a test
BLOCKED rather than inferring success from source inspection, emulator behavior,
or a mocked test.

## Release gate

Physical validation remains a required production gate. In particular,
verify notification access, consent revocation, encryption, retention,
restart/failure recovery, duplicate prevention, multiple sources, background
restrictions, and the oversized-notification policy on supported hardware.
No device behavior is certified by this plan.
