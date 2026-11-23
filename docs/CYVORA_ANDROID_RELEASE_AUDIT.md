# Cyvora Android Release Audit

## Verified

- Stable tag and default-branch ancestry validation source is implemented.
- The build checks out the validated target SHA.
- Signing and publishing use separate protected-environment names.
- Package ID: `com.example.cyvora_mobile`.
- Pubspec version: `1.0.3+3`.
- Release APK build: **PASS**.
- Release AAB build: **PASS**.
- Release policy tests: **16 PASS**.
- Signing keystore and key alias are now explicitly checked before Android
  builds.

## Failed

Locally built release artifacts do not match the fixed production certificate
SHA-256 configured in `flutter/scripts/validate_android_release.py`:

`d732eaa269a8707b2447c73aee5a14885d030d59b9dc7382302321c750ad3afa`

The exact APK validator result was:

`APK signer does not match the established production certificate`

Do not replace the expected fingerprint merely to make CI pass.

## Blocking requirements

1. Owner confirms the authorized Play Store release certificate.
2. The protected `android-signing` Environment contains the matching keystore,
   alias, and passwords.
3. APK and AAB sign with the same certificate.
4. The previous published APK's versionCode is lower than `3`.
5. Re-run artifact validation and publish evidence.

## Not verified

- Protected GitHub Environment approval rules.
- Exact public workflow log for run `45045534291`.
- Upload and Play App Signing certificate chain.
- Physical-device release-only behavior.
- OEM notification-listener behavior.
