# Appwrite Deployment

## Prerequisites

Install Appwrite CLI and authenticate interactively. Never place API keys in
repository files or shell scripts.

```powershell
appwrite login
appwrite projects list
```

`appwrite/appwrite.json` contains public project metadata only:

- project ID: `6b07c3da0034d57913c7`
- endpoint: `https://sgp.cloud.appwrite.io/v1`
- region: Singapore

## Development/staging process

1. Use an isolated development or staging Appwrite environment.
2. Create the database, tables, indexes, bucket, and platform registrations
   through the Console or an SDK deployment script.
3. Configure Function secrets in the Function Console.
4. Configure Flutter and Laravel environment variables.
5. Run Flutter, Laravel, and Supabase tests plus staging integration tests.
6. Produce reconciliation evidence before requesting cutover authorization.

No production cutover or destructive operation is automated in this repository.
