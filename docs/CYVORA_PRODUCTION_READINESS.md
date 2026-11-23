# Cyvora production readiness

**Assessment date:** 2026-11-23
**Branch/commit inspected:** `fix/mlkit-release-crash` / `6ab63fe`
**Verdict:** **NOT PRODUCTION READY**
**Production changes:** None

## Summary

The Flutter + Supabase architecture is intact, and Laravel is the intended
Super Admin application. Current local code includes mandatory MFA enrollment
for privileged roles, AAL2 checks across Laravel/Edge Functions/RLS, and
reauthentication before sensitive panel mutations. Local Flutter, Node, and
Laravel tests pass, and the Android debug APK builds.

These results do not establish production readiness. Supabase migrations and
RLS have not been run against an isolated database, deployed Edge Function
revisions and Auth settings have not been checked, and live provider behavior
has not been verified. Previous local Android artifact checks found an
APK/AAB signing identity mismatch against the release validator; the
authorized production signing identity must be confirmed by the owner.
iOS/device testing is unavailable on this Windows host.

## Status by area

| Area | Status | Evidence / remaining work |
|---|---|---|
| Flutter client and Auth | IMPLEMENTED; locally VERIFIED | Analysis and 67 widget/unit tests pass. No physical-device/iOS verification. |
| Laravel Super Admin | IMPLEMENTED; locally VERIFIED | Separate Auth, four server-assigned roles, route permissions, mandatory MFA, sensitive-action reauthentication, privacy-limited views, audit/deletion workflows. 28 Laravel tests pass using HTTP fakes. |
| Supabase role/MFA boundary | SOURCE IMPLEMENTED; NOT DATABASE-VERIFIED | Migration `202611230003_require_mfa_for_admins.sql` updates the restrictive MFA function; Edge Function helper rejects factorless/AAL1 privileged calls. SQL/RLS and hosted Auth behavior are not tested. |
| Database/RLS/migrations | NOT VERIFIED | pgTAP suite prepared, but Supabase CLI/PostgreSQL runtime unavailable. Do not infer deployment from source files. |
| Edge Functions | SOURCE TESTED; DEPLOYMENT UNKNOWN | 98 Node tests cover mocked/static behavior. Deno runtime, hosted function revisions, and live Auth/MFA claims were not verified. |
| AI and URL providers | PARTIALLY IMPLEMENTED; LIVE STATE UNKNOWN | Consent gates, server-side secrets, minimization, budgets, fallback, and failure handling exist in source. No provider keys, live connectivity, billing limits, or provider retention were checked. |
| Family Protection | IMPLEMENTED IN SOURCE; RLS NOT VERIFIED | Invitation lifecycle, family ownership boundaries, admin metadata views, and audit handling exist. Cross-account behavior needs staging database tests. |
| Scam intelligence | IMPLEMENTED IN SOURCE; RELEASE GATES NOT LIVE-VERIFIED | Existing reviewer separation and dataset release checks remain in the Edge Function/database path. Hosted policy/function state is unknown. |
| Android notification monitoring | IMPLEMENTED; DEVICE TESTING REQUIRED | Consent-gated encrypted local queue, event-scoped scan idempotency, and retention are in source. Permission revocation, key recovery, process death, reboot, and OEM behavior need device tests; the idempotency SQL/pgTAP test has not run. |
| Android release/signing | BLOCKED | Prior local APK/AAB checks found a signer mismatch against the expected production identity. Protected CI signing secrets and GitHub environments were not accessed. |
| iOS | BLOCKED | Xcode/signing/provisioning are unavailable on Windows; no iOS device test was run. Existing `com.example` identifiers require owner confirmation before release. |
| Production configuration and operations | NOT VERIFIED | No live credentials or infrastructure settings were inspected or changed. |

## Release blockers

1. **Validate in isolated Supabase staging.** Apply only migrations missing
   from the staging ledger, in timestamp order. Ensure `pg_cron` is available
   for notification-idempotency retention. Run the pgTAP security and
   notification-idempotency suites; verify RLS role isolation, admin MFA,
   audit immutability, family boundaries, invitation lifecycle, scan replay,
   and RPC grants.
2. **Verify hosted Auth and functions.** Confirm the Auth factor configuration,
   AAL2 claims, recovery redirects, function revisions, role checks, moderator
   separation, and dataset release behavior.
3. **Resolve Android signing ownership.** The owner must confirm the authorized
   certificate and supply matching protected signing configuration. Do not
   change the validator's expected identity to make artifacts pass.
4. **Complete supported-device testing.** Exercise notification consent,
   expiry/deletion, background execution, and permission revocation on Android;
   build/sign/test iOS on macOS/Xcode.
5. **Verify provider controls.** Confirm real model availability, spend caps,
   rate limits, privacy/retention terms, and failure behavior in staging.
   Request quotas are not a monetary cap.
6. **Use an MFA recovery runbook.** Keep recovery out-of-band and require
   re-enrollment; never create a temporary AAL1 administrator session.

## Safe deployment sequence

Follow the [Super Admin deployment guide](CYVORA_SUPER_ADMIN_DEPLOYMENT.md):
stage migrations and functions in an isolated project, test the exact role and
MFA boundaries, deploy Laravel with server-only secrets/HTTPS/secure sessions,
provision an existing verified Auth account through the trusted command, and
verify first-login factor enrollment before enabling production access.

The deployment guide is a procedure, not a record of a completed deployment.
No production database, account, provider, signing identity, or GitHub setting
was changed during this audit.

## Related documentation

- [Full security audit](CYVORA_FULL_SECURITY_AUDIT.md)
- [Architecture map](CYVORA_ARCHITECTURE.md)
- [Super Admin guide](CYVORA_SUPER_ADMIN_GUIDE.md)
- [Supabase integration](CYVORA_SUPABASE_INTEGRATION.md)
- [Test results](CYVORA_TEST_RESULTS.md)
- [Deployment guide](CYVORA_SUPER_ADMIN_DEPLOYMENT.md)
