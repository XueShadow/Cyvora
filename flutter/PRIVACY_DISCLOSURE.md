# Cyvora Notification Protection Disclosure

## Required prominent disclosure

Cyvora Notification Protection

Cyvora can monitor notifications from messaging applications you explicitly
select to help identify suspicious links, phishing attempts, and scam messages.

Notification access may expose message previews and other notification content
from the selected applications. Cyvora filters notifications locally according
to the applications and sensitive-content rules you enable. Obvious one-time
codes, passwords, passcodes, PINs, and numeric-only codes are not intentionally
stored. Automated filtering is heuristic and is not a guarantee that every
sensitive value will be detected.

Eligible notification previews are encrypted on this Android device and expire
according to the retention period you choose: 1, 7, or 30 days. Cyvora does not
send notification content automatically. A preview is transmitted for analysis
only after you review it and select Scan. Sending it to a configured AI provider
still requires the app's separate per-scan consent where applicable.

Cyvora does not need notification access for manual message scanning, URL
scanning, or screenshot scanning.

You can disable Notification Protection, deselect applications, delete queued
previews, or revoke Android notification-listener access at any time.

## Explicit actions

- Enable Notification Protection
- Not Now

Dismissal, navigation, or pressing Back is not consent. Consent is stored
only after a separate affirmative action. Android notification-listener access
is not requested until the user has seen this disclosure and chosen to continue.

## Data handling

- Package names are checked against a fixed supported-app allowlist.
- A separate Android special-access setting must be enabled.
- Ongoing/group-summary notifications are ignored.
- Promotional notifications are ignored.
- Content is title/text-limited before local storage.
- Retained content is encrypted with Android Keystore-backed AES/GCM.
- Queued previews are user-reviewed.
- The selected app, title, text, timestamp, and queue identifier are stored
  only for the queue and only while retention and consent remain valid.
- Disabling monitoring or deselecting all apps deletes pending previews.
- Revoking Android notification access disables the live source and should
  clear or stop monitoring according to the native/app lifecycle controls.

## What is not implemented

- Cyvora does not request `POST_NOTIFICATIONS`.
- Cyvora does not implement push notification delivery.
- Cyvora does not monitor calls, SMS databases, call logs, browsing, or
  emergency services.
- Cyvora does not change the default SMS application.
- Cyvora does not automatically transmit queued notifications.

## Implementation verification

- Implemented in app source and native Android listener.
- The final release APK declares no SMS, Call Log, location, contacts, camera,
  broad-storage, accessibility, foreground-service, or app-notification runtime
  permission.
- Notification listener access is special Android access and remains off until
  explicitly enabled.
- Package filtering and sensitive-preview filtering are implemented locally.
- Final runtime and revoked-access behavior require a physical-device test.
