# Appwrite Security

Authorization is server-owned:

- Never grant broad table-level read/update/delete access.
- Create user-owned rows with explicit row permissions.
- Keep server-only records inaccessible to client sessions.
- Validate the current Appwrite user and role in every privileged Function.
- Administrative roles must come from a server-controlled role record.
- Do not trust Flutter-supplied role, family, owner, or MFA claims.
- Perform family membership checks server-side.
- Use private storage with explicit per-file permissions.
- Audit privileged changes without logging secrets or provider credentials.

Appwrite MFA support does not itself prove server-verifiable privileged MFA.
Privileged administrator operations remain gated until a verified challenge
session can be proven server-side in a staging POC.
