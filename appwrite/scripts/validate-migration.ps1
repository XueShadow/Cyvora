param(
    [switch]$RequireSecrets
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$manifestPath = Join-Path $root 'appwrite\schema\database.json'

if (-not (Test-Path $manifestPath)) {
    throw "Missing schema manifest: $manifestPath"
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
if ($manifest.tables.Count -ne 38) {
    throw "Schema manifest must contain 38 tables; found $($manifest.tables.Count)"
}

foreach ($table in $manifest.tables) {
    if (-not (Test-Path (Join-Path $root $table.sourceMigration))) {
        throw "Missing source migration: $($table.sourceMigration)"
    }
}

$requiredFlutter = @('APPWRITE_ENDPOINT','APPWRITE_PROJECT_ID','APPWRITE_DATABASE_ID')
foreach ($name in $requiredFlutter) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
        Write-Warning "Missing environment variable: $name"
    }
}

if ($RequireSecrets) {
    foreach ($name in @('APPWRITE_API_KEY','AI_PROVIDER_API_KEY')) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            throw "Missing server secret: $name"
        }
    }
}

Write-Host "Appwrite migration manifest validated: $($manifest.tables.Count) tables."
