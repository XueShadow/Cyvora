# Appwrite Setup

## Public Flutter configuration

Use dart defines; do not put server credentials in Flutter:

```powershell
flutter run `
  --dart-define=APPWRITE_ENDPOINT=https://sgp.cloud.appwrite.io/v1 `
  --dart-define=APPWRITE_PROJECT_ID=6b07c3da0034d57913c7 `
  --dart-define=APPWRITE_DATABASE_ID=<staging-database-id>
```

Required public values:

- `APPWRITE_ENDPOINT`
- `APPWRITE_PROJECT_ID`
- `APPWRITE_DATABASE_ID`

## Appwrite Console actions

In a separate development/staging project or environment:

1. Create the `cyvora` TablesDB database.
2. Create and configure the 38 logical tables listed in `appwrite/schema/database.json`.
3. Create the private `profile-avatars` bucket with a 5 MB limit and JPEG/PNG/WebP MIME allowlist.
4. Register Android platform `com.example.cyvora_mobile`, iOS platform `com.example.cyvoraMobile`, and Web platform `localhost`.
5. Configure verification and recovery redirect URLs to approved application origins.
6. Enable only required authentication methods and MFA factors.
7. Create server API keys with minimum scopes for Laravel and Functions.
8. Deploy the Scam, Family, Admin, Account Lifecycle, and scheduled maintenance Functions.

Do not expose the server API key through Flutter or browser output.
