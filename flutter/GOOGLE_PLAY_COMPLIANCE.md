# Cyvora Google Play Compliance

## Scope

This report records source and build evidence for Android permission and privacy
controls. It is not a Google Play approval determination.

## Current position

- Cyvora does not declare or request SMS or Call Log permissions.
- Cyvora does not request broad storage, location, contacts, camera, or
  accessibility permissions.
- Cyvora does not become or replace the default SMS application.
- Manual message scanning remains available without notification access.
- Notification scanning is not enabled by first launch or silently.
- Android notification listener access remains a separate, optional special
  access flow.
- Cyvora requests no Android app-notification runtime permission because its
  own push notifications are not implemented.
- Screenshot/profile-image selection uses the system photo picker.

## Notification listener risk

Notification listener access exposes notification content and is sensitive
special access. Cyvora uses it only for the documented scam-monitoring feature:

1. Show prominent disclosure.
2. Require explicit in-app consent.
3. Require Android notification-listener access.
4. Require at least one selected supported messaging app.
5. Filter package names and sensitive preview text locally.
6. Encrypt retained previews locally.
7. Require a separate user action before manual analysis.
8. Stop capture and delete previews when consent, access, or app selection is
   disabled.
9. Let users revoke access in Android settings.

Google Play may review this feature as a security or sensitive-access feature.
The app listing, privacy policy, Data Safety responses, video demonstration,
and Play Console declarations must accurately describe it.

## Restricted SMS and Call Log permissions

No SMS or Call Log declaration is required for the current manifest. If future
requirements add these permissions, a Play Console permissions declaration will
be required and approval is not guaranteed. Cyvora currently does not qualify
by assumption; it is not a default SMS/Phone/Assistant handler.

## Data Safety and privacy policy

The privacy policy and Play Console Data Safety section must disclose:

- Account name, email, and authentication data.
- Supabase Auth and SMS MFA data.
- Scan metadata and server-processed content.
- Optional AI and reputation-provider transfers.
- Family and report data.
- Android notification listener access.
- Selected app names/packages and notification preview collection.
- Local encrypted preview storage and retention.
- Manual review and separate analysis consent.
- Sensitive-preview filtering.
- Third-party SDK data handling.

The Play Console Data Safety section must be reviewed against the actual
application and Supabase/provider configuration and kept in sync with future
updates.

## Required Play Console declarations

At present:

- No SMS or Call Log declaration is expected for the final manifest.
- Notification-listener access may require policy review and a feature
  declaration depending on Play Console categorization and the final app
  listing. Google Play review should be expected for a security app using
  sensitive notification access.
- No location, storage, camera, contacts, accessibility, package-visibility,
  foreground-service, or all-files declaration is expected.

## Remaining policy risks

- Notification listener special access is highly sensitive and may be rejected
  if the listing/disclosures do not present the core security purpose.
- A Notification Listener application may face additional policy review.
- Filtered previews may still expose personal or financial data.
- Third-party AI/provider terms and retention require verification.
- The app has a privacy policy but hosted/Data Safety consistency remains an
  owner/compliance review.
- Physical Android behavior and Play Store review are not verified.

## Verification evidence

- Clean dependency restore: passed.
- Flutter analysis: passed with no issues.
- Flutter tests: 73 passed.
- Android app unit tests: passed.
- Android release policy tests: 20 passed.
- Android release APK build: passed.
- Web build: passed.
- Final release APK permission dump contains `INTERNET` and an app-specific
  signature-level dynamic-receiver permission only.
- No restricted SMS/Call Log/media/location/contact/camera/storage/
  accessibility/foreground permission is present in the final APK.
- The aggregate Gradle `testDebugUnitTest` task also runs plugin dependency
  suites and previously hit third-party image-picker fixture failures;
  narrowing to `:app:testDebugUnitTest` passed Cyvora's app unit suite.
- Play approval, hosted Supabase behavior, provider DPA/retention, Data Safety
  accuracy, physical Android listener behavior, and OEM compatibility remain
  unverified.
