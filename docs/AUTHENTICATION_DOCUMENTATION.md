# Cyvora Authentication Documentation

Cyvora uses Supabase Auth for:

- email/password registration and login;
- email confirmation;
- password reset/update;
- session persistence and auth-state transitions;
- TOTP/SMS MFA;
- server-assigned role checks;
- account deletion.

The Flutter client never supplies authorization for another account. Edge
Functions call `auth.getUser(accessToken)` and privileged operations use the
service role only on the server.

MFA must be complete (AAL2) for privileged roles. Regular users retain opt-in
MFA behavior. Hosted Auth redirect URLs, SMTP/SMS providers, token settings,
and account lifecycle behavior require external project verification.
