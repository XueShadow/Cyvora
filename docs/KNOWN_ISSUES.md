# Cyvora Known Issues

## External blockers

1. Supabase CLI and Docker daemon unavailable; hosted/local migrations, RLS,
   Cron, Auth, Storage, and Edge runtime cannot be verified.
2. No real test Supabase account/credentials, SMTP, SMS, or provider keys.
3. No Android physical/emulator device or ADB runtime.
4. Ollama is explicitly excluded from provider routing.
5. Push notification delivery is not implemented despite saved preferences.
6. iOS build environment unavailable.
7. Web server on port 8765 was stopped at the final HTTP probe.
8. Live Play Console, Data Safety, and Google Play review remain external.

## Source limitations

- The dashboard still has a large shared view and transient state.
- The dashboard repository remains broader than dedicated feature data sources.
- Notification listener/OEM behavior remains physical-device work.
- Provider DPA, billing, model availability, and live response compatibility
  require staging credentials.
- CAPTCHA protection is not implemented for the app's supported auth surface;
  anonymous accounts are not exposed as a supported flow.
