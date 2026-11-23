# Cyvora Docker Image Scan Review

## Status

**UNVERIFIED / NOT ATTRIBUTED TO A CYVORA IMAGE.** This review is based on a
user-provided, cropped Docker Scout screenshot. It is not a scan executed by
this validation. The visible image reference is truncated (`public.ecr.aws/...`),
and no full tag, digest, package/version listing, scanner database timestamp,
or repository Dockerfile/Compose definition was provided or found. Do not treat
these entries as confirmed vulnerabilities in a Cyvora release image.

The local repository contains no Dockerfile or Compose file that identifies
the scanned image. The screenshot shows an Alpine 3.23 base layer and build
layers, but does not establish which image or runtime those layers belong to.

## What the screenshot reports

The expanded vulnerability list displays five findings, all marked Medium,
with scores from 6.1 to 6.5. Four show a fixable checkmark; CVE-2026-58055
does not. The package names and installed versions are not visible.

| CVE | Reported score | Component/advisory match | High-level issue | Screenshot fixable |
|---|---:|---|---|---|
| CVE-2021-41182 | 6.5 Medium | jQuery UI before 1.13.0 | XSS risk in Datepicker `altField` handling of untrusted values. | Yes |
| CVE-2021-41184 | 6.5 Medium | jQuery UI before 1.13.0 | XSS risk in the `.position()` `of` option when supplied untrusted values. | Yes |
| CVE-2021-41183 | 6.5 Medium | jQuery UI before 1.13.0 | XSS risk in Datepicker `*Text` options with untrusted values. | Yes |
| CVE-2026-58055 | 6.3 Medium | nghttp2/nghttpx through 1.69.0 | HTTP request/response smuggling involving Upgrade requests and `Content-Length`, when the affected proxy/backend conditions apply. | No |
| CVE-2022-31160 | 6.1 Medium | jQuery UI before 1.13.2 | XSS risk in checkboxradio refresh when initial label content contains encoded HTML entities. | Yes |

Advisory references: [CVE-2021-41182](https://api.osv.dev/v1/vulns/CVE-2021-41182),
[CVE-2021-41183](https://api.osv.dev/v1/vulns/CVE-2021-41183),
[CVE-2021-41184](https://api.osv.dev/v1/vulns/CVE-2021-41184),
[CVE-2022-31160](https://api.osv.dev/v1/vulns/CVE-2022-31160), and
[CVE-2026-58055](https://api.osv.dev/v1/vulns/CVE-2026-58055).

The screenshot's Alpine summary row also appears to show a red severity count,
while the expanded list shows five Medium entries. Because the image is
cropped and the selected-layer scope is unclear, the overall image severity
totals cannot be reconciled from this screenshot. Obtain the full scan report
before asserting that the image contains only Medium findings.

## Remediation guidance, conditional on image identity

1. Obtain the complete repository/image name, tag, immutable digest, and scan
   export including package names, installed/fixed versions, affected layers,
   and scanner database timestamp.
2. Verify whether the affected packages are present in the shipped runtime
   image or only in build/development layers, and whether the vulnerable
   jQuery UI options or nghttpx proxy path are reachable in the application.
3. If the image contains affected jQuery UI, upgrade to at least 1.13.2 and
   rebuild/rescan. Confirm the lockfile and deployed asset actually resolve
   to the fixed version.
4. For nghttpx, use a vendor package/build containing the upstream fix and
   verify its version against the scanner/vendor advisory. Do not infer that
   no upstream fix exists solely because this screenshot has no fixable
   checkmark.
5. Rebuild the exact release image, scan by digest, and verify both the
   detailed CVE list and the severity summary. Record the image digest and
   remediation evidence.

No package was changed, no image was rebuilt, and no vulnerability was
confirmed in a Cyvora artifact during this review.
