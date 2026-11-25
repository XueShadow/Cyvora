# Cyvora Permission Audit

The final Android release declares `INTERNET` and an app-specific signature-level
dynamic receiver permission. The notification listener is a special-access
service and is not a runtime permission.

No SMS, Call Log, Contacts, Location, Camera, broad Media/Storage,
Accessibility, All Files, Query All Packages, Foreground Service, or
POST_NOTIFICATIONS permission is declared.

Third-party `ACCESS_NETWORK_STATE` is removed through the manifest merger.
Screenshot/profile selection uses platform photo pickers; no broad photo-library
permission is requested.

Live Android listener behavior and Play Store declaration review remain
not tested.
