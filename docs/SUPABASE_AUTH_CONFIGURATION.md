# Supabase Authentication Configuration for Cyvora

**Status: BLOCKED / NOT VERIFIED.** This is the required staging setup guide;
no hosted Supabase project was changed during this remediation.

## 1. Redirect URLs

In Supabase Dashboard → **Authentication → URL Configuration**:

1. Set **Site URL** to the canonical production Web origin (scheme and host,
   with no path).
2. Add exact redirect allow-list entries for each deployed Web origin and each
   Web development origin used by the team. Flutter Web currently redirects to
   `Uri.base.origin`, with `http://localhost:3000` as its fallback; include the
   actual development port/origin in use.
3. Add the mobile callback URI exactly:
   `io.supabase.cyvora://login-callback/`
4. Do not use a broad wildcard redirect. Remove obsolete origins and review
   the allow-list whenever a host changes.

The Android manifest declares the `io.supabase.cyvora` scheme and
`login-callback` host. iOS registers the same scheme in
`ios/Runner/Info.plist`. Verify callback handling on installed Android and iOS
builds as well as Web.

## 2. Email confirmation and recovery templates

In Dashboard → **Authentication → Providers → Email**:

- Enable email signups and require email confirmation for newly registered
  accounts. Keep confirmation enforcement enabled in production.
- Configure a verified sender and production SMTP provider. For production
  delivery, configure SPF/DKIM and monitor provider failures/rate limits.
- Keep the confirmation and password-recovery templates on Supabase's
  confirmation flow (for example `{{ .ConfirmationURL }}`) so Supabase
  validates the one-time token and applies the request's allowed redirect.
  Do not place access tokens, refresh tokens, OTPs, or MFA secrets in custom
  application URLs.
- Set password policy to at least 12 characters and an appropriate complexity
  policy consistent with the Flutter rule (12+ characters and at least three
  of uppercase/lowercase/number/symbol). Server policy is authoritative.
- Keep recovery links short-lived and one-time; use Supabase's PKCE flow and
  test expired, reused, malformed, missing-state, and cross-browser links.

The app's reset/resend success copy is generic. A successful API response means
the request was accepted; it does not prove mailbox delivery. Confirm delivery
through staging mail-provider logs.

## 3. MFA and privileged roles

In Dashboard → **Authentication → Multi-Factor Authentication** and the
project's Auth provider settings:

- Enable TOTP for users who need it. Enable/configure SMS only if SMS factors
  are an approved supported method, with provider credentials kept server-side.
- Confirm challenge expiry, rate limits, and factor enrollment/verification
  settings in a staging project.
- Assign privileged roles only through trusted server-side provisioning into
  `app_metadata`; never accept a role from editable `user_metadata` or a client
  profile field.
- Confirm the deployed `mfa_access_allowed()` policy requires a verified factor
  and AAL2 for `super_admin`, `admin`, `moderator`, and `support_admin`.
- Verify privileged Edge Functions and Laravel Super Admin routes independently
  validate the user, trusted role, and AAL2; client-side routing is not an
  authorization boundary.

Do not grant service-role credentials to Flutter. Keep service-role keys in
server-side secret storage only.

## 4. Staging acceptance checks

Use an isolated, disposable Supabase project and test accounts only:

1. Register an account; verify confirmation and that no session is treated as
   authenticated before confirmation.
2. Open the confirmation link on Android and Web; verify the exact redirect and
   same-browser PKCE behavior.
3. Request resend/reset for both known and unknown addresses; verify identical
   user-facing responses and inspect provider delivery logs separately.
4. Test expired, reused, malformed, and cross-browser links. Confirm a normal
   sign-in callback is not routed as a password-recovery event.
5. Update a password from a valid recovery session; confirm the new password
   works and the old password does not.
6. Restart Android/Web clients with a valid session, test token refresh,
   account switching, local logout, and invalid/expired refresh tokens.
7. Test TOTP and SMS (if enabled): valid/invalid codes, expired challenges,
   resend limits, and cooldown.
8. Test privileged users with no factor, an unverified factor, AAL1, and AAL2.
   Verify each privileged database/function request fails closed until verified
   AAL2.
9. Run `supabase/tests/security_boundaries.test.sql` and any pgTAP suite against
   the isolated database. Verify own-row access, cross-user denial, anonymous
   denial, invalid JWT rejection, and role-escalation denial.

These checks were not run here: Supabase CLI and `psql` were unavailable, and
the installed Docker client could not connect to its daemon.
