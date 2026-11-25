# Cyvora Privacy and Data Flow

```text
Manual text/URL/screenshot
  -> Flutter
  -> server
  -> local rules/provider checks
  -> scan metadata saved
  -> original input not persisted

Notification
  -> Android listener
  -> selected-package and sensitive-content filters
  -> Android Keystore AES/GCM queue
  -> user selects review/scan
  -> optional AI consent and server processing
  -> queue deletion/expiry
```

The app uses explicit AI and URL reputation consent. The privacy policy must
continue to disclose Supabase, account data, SMS MFA, AI/reputation providers,
family sharing, notification previews, retention, and account deletion.

No secrets belong in Flutter or the repository. Provider and service-role
credentials remain server-side.
