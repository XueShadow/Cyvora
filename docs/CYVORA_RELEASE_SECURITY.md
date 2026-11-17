# Cyvora Android Release Security Review

## Scope and verdict

This is a source/workflow review of
`.github/workflows/android-release.yml` and its local release-policy and
artifact-validation tests. The workflow source has safeguards for stable-tag
validation, branch ancestry, pinned actions, least-privilege permissions,
separate signing/publishing environments, and draft-only publication.

**Workflow source: conditionally acceptable for owner-configured staging
validation. Production release: NOT CLEARED.** GitHub repository settings,
environment approvals, secret placement, and an Android release run were not
observable in this validation. An independent source review reported no
confirmed exploitable vulnerability in the reviewed workflow.

## Source-level controls observed

| Control | Source result | Limit |
|---|---|---|
| Action immutability | Third-party actions are pinned by full commit SHA. | Recheck every new or updated action reference. |
| Stable release refs | Stable `vMAJOR.MINOR.PATCH` tags are validated; the tagged commit must be an ancestor of the default branch. Manual dispatch is restricted to that branch. | GitHub tag creation/update rules still require owner verification. |
| Signing and publishing boundary | `android-signing` and `android-publish` are separate named Environments. | Workflow YAML does not create reviewers or prove which secrets are stored in each environment. |
| Permissions | Build/signing jobs use restricted permissions; write permission is limited to publication. | Confirm effective permissions and any organization-level defaults in GitHub. |
| Artifact validation | APK/AAB package, version, supported ABI/permissions, and signing certificate are checked before publication. | No artifact from a release run was produced or validated in this pass. |
| Publication | Release is created as a draft. | Confirm only authorized maintainers can publish the draft. |
| Local policy tests | 15 release-policy tests passed previously. | They do not verify GitHub rulesets or protected environments. |

GitHub CI run `44074458843` passed Flutter and backend jobs for source commit
`659b79d`. Current branch HEAD is `392231280bbfaf1dc09096a77ebe4cbf0542e0bd`;
the release workflow has no run on this branch, and the current uncommitted
changes have no CI run.

## Required repository-owner checks

An administrator should verify and record:

- `android-signing` and `android-publish` Environments exist and have required
  reviewers; prevent self-approval where supported.
- Environment deployment branches/tags are restricted to approved release
  refs; normal pull requests cannot access signing secrets.
- Signing values are stored only as `android-signing` Environment secrets:
  `ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and
  `KEY_PASSWORD`. Secret presence and values were not inspected here.
- Default-branch rules require review/status checks and prevent unauthorized
  force-pushes.
- A `v*` tag ruleset restricts tag creation, update, and deletion to release
  managers.
- Only the intended publishing job can write releases; draft review,
  checksums, and artifact signature are validated before publication.
- Organization-level Actions policies, token permissions, and allowed-action
  settings do not broaden the workflow's requested permissions.

## Identity and release artifact

The workflow/artifact validator currently expects Android application ID
`com.example.cyvora_mobile`. The owner must confirm that this is the intended
Play Store identity; it still has an example-style namespace. Do not change
the application ID or signing identity without checking the existing store
listing and update lineage.

Before release, run the workflow on a protected stable tag, verify the draft
APK/AAB package ID, version, target/min SDK, ABI set, permissions, certificate
fingerprint, and checksums, and test installation/update behavior on a
physical device. No release workflow run, signed release artifact, or GitHub
settings verification is claimed by this report.
