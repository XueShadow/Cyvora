# Cyvora Android Release Security Guide

## Status

The workflow source is hardened and locally policy-tested. GitHub repository
rules, environment reviewers, environment-secret placement, and a real signed
release have not been verified. This guide describes the required owner setup;
it does not configure GitHub automatically.

## Required owner configuration

1. Protect the default release branch with reviewed changes and block force
   pushes/deletions.
2. Add a tag ruleset for stable `v*` tags. Restrict create/update/delete to
   release managers; prevent tag retargeting after publication.
3. Create GitHub Environments named `android-signing` and `android-publish`.
   Add required reviewers and restrict deployment branches/tags. Prevent
   self-review where the repository plan supports it.
4. Put `ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and
   `KEY_PASSWORD` only in `android-signing` environment secrets. Remove
   repository-level duplicates. Do not copy real values into local tests,
   issues, logs, or documentation.
5. Keep `contents: write` limited to the `publish-release` job. Third-party
   Actions in the workflow must remain pinned to verified commit SHAs.

## Release validation behavior

- Push releases accept stable `vMAJOR.MINOR.PATCH` tags only.
- Manual dispatch must run from the default branch and supply an existing
  stable tag. The validator resolves the exact tag commit and checks that it
  is an ancestor of the fetched default branch.
- The signing/build job checks out the validated commit SHA, not the current
  default-branch tip. It runs tests and artifact checks before upload.
- `validate_android_release.py` verifies package ID, version name/code, tag
  match, required ABIs/permissions, APK/AAB signatures, certificate identity,
  and that the version code exceeds the prior release.
- Signing requires approval through `android-signing`; publishing requires
  approval through `android-publish`. The publish job has `contents: write`
  and creates a draft for human review.
- An owner must inspect draft notes, checksums, signer identity, and release
  artifacts, then publish the draft manually.

## Safe test policy

Run local policy tests without signing credentials:

```powershell
Set-Location flutter\scripts
python -m unittest test_validate_android_release_ref test_validate_android_release test_android_release_workflow
```

Tests use temporary Git repositories and do not call GitHub or consume signing
secrets. They cover malformed/missing tags, incorrect refs, unapproved
commits, dispatch restrictions, artifact-version mismatch, and static
workflow permission/environment rules. They do not prove GitHub Environments,
tag rulesets, or signing secrets are configured correctly.

Do not run a real release with dummy credentials against Cyvora. To validate
the hosted approval path end-to-end, use a disposable repository, dummy
signing materials, and owner-approved test environments.

## Manual release checklist

- [ ] Confirm the commit is reviewed and present on the protected default
  branch.
- [ ] Confirm the release tag matches `flutter/pubspec.yaml` and points to
  that approved commit.
- [ ] Confirm required reviewers approved both protected Environments.
- [ ] Confirm the signing job validated the APK/AAB identity, version, and
  checksums.
- [ ] Review the draft release and artifacts before publishing.
- [ ] Preserve the existing signing identity; do not rotate or replace it
  without an approved migration plan.

No signing/release build or GitHub settings change was performed as part of
the local remediation.
