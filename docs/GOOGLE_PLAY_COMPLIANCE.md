# Cyvora Google Play Compliance

Cyvora currently uses no restricted SMS/Call Log permissions and does not replace
the default SMS or Phone app. Manual scans remain usable without notification
access.

Notification listener access is optional, consent-gated, package-filtered,
locally encrypted, retention-bounded, and user-revocable. Sensitive OTP/password
filters are heuristic and do not guarantee every secret is blocked.

No app-notification runtime permission is requested because push delivery is not
implemented.

## External Play Console work

Verify and maintain the Data Safety section, privacy policy, store listing,
notification-listener feature disclosure, account deletion, SDK disclosures,
provider sharing, and third-party terms.

SMS/Call Log declarations are not required for the current manifest. A
notification-listener feature may receive enhanced policy review. No guarantee
of Play approval is made.
