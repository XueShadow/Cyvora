# Cyvora Remaining Issues

## Blocked

| Issue | Severity | Blocker |
|---|---|---|
| Android release signer mismatch | HIGH | Owner must confirm the authorized production certificate and configure matching signing secrets. |
| Supabase migration and pgTAP execution | HIGH | Docker daemon and Supabase CLI/PostgreSQL runtime unavailable. |
| Hosted Supabase Auth/RLS/Edge verification | HIGH | No staging project or credentials used. |
| Live provider validation | HIGH | No provider credentials or live requests used. |
| GitHub protection and Environment rules | HIGH | GitHub settings require authenticated owner inspection. |
| Physical Android/OEM validation | MEDIUM | No device or adb session available. |
| iOS build/device validation | MEDIUM | Windows host without Xcode/macOS. |

## Failed

- Local Android release validator rejects the local release signer against the
  established production certificate.
- The prior GitHub release run `45045534291` has not been promoted or published
  by the validated artifact gate.

## Requires human approval

- Merge to `main`.
- Android signing identity and Play Store certificate chain.
- Production migration deployment.
- Provider activation and budget configuration.
- Environment protection, branch protection, tag rules, and draft publication.
