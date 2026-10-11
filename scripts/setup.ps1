<#
.SYNOPSIS
  One-time (and repeatable) development setup for the GoHard rebuild.
  Creates ONLY the dedicated container/database/volume, applies migrations explicitly and seeds the exercise catalog.
  It never touches other containers, databases or projects, and never prints secrets.
#>
. "$PSScriptRoot\common.ps1"

Step 'Checking prerequisites'
Assert-DotNet10
Assert-Docker

$running = docker ps --filter "name=^/$DbContainer$" --format '{{.Names}}'
if (-not $running -and (Test-PortInUse $DbPort)) {
    Fail "Port $DbPort is already used by another process. Free it or change `$DbPort in scripts\common.ps1 and GOHARD_DB_PORT."
}

if (-not (Test-Path $EnvFile)) {
    Step 'Creating local database credentials (infrastructure\.env.local, not committed)'
    "GOHARD_DB_PASSWORD=$(New-Secret 24)`nGOHARD_DB_PORT=$DbPort" | Set-Content -Path $EnvFile -Encoding ascii
}
$envValues = @{}
Get-Content $EnvFile | ForEach-Object { $k, $v = $_ -split '=', 2; if ($k) { $envValues[$k.Trim()] = $v.Trim() } }

Step "Starting dedicated PostgreSQL container '$DbContainer' on 127.0.0.1:$DbPort"
docker compose --env-file $EnvFile -f $ComposeFile up -d --wait
if ($LASTEXITCODE -ne 0) { Fail 'The dedicated PostgreSQL container did not become healthy.' }

if (-not (Test-Path $LocalConfig)) {
    Step 'Writing API local configuration (appsettings.Local.json, not committed)'
    @{
        ConnectionStrings = @{ Default = "Host=127.0.0.1;Port=$DbPort;Database=$DbName;Username=$DbUser;Password=$($envValues['GOHARD_DB_PASSWORD'])" }
        Auth              = @{ SigningKey = (New-Secret 48) }
    } | ConvertTo-Json -Depth 4 | Set-Content -Path $LocalConfig -Encoding utf8
}
# Guard: provisioning may only ever target the dedicated rebuild database.
$configured = (Get-Content $LocalConfig -Raw | ConvertFrom-Json).ConnectionStrings.Default
if ($configured -notmatch "Database=$DbName(;|$)" -or $configured -notmatch "Port=$DbPort(;|$)") {
    Fail "appsettings.Local.json does not point at $DbName on port $DbPort. Refusing to migrate anything else."
}

Step 'Restoring and building the API'
dotnet build $ApiProject --nologo -v q
if ($LASTEXITCODE -ne 0) { Fail 'API build failed.' }

Step 'Applying migrations explicitly'
dotnet run --project $ApiProject --no-build -- migrate
if ($LASTEXITCODE -ne 0) { Fail 'Migration failed or the schema is not ready.' }

Step 'Seeding the exercise catalog (reference data only; no accounts, workouts or food)'
dotnet run --project $ApiProject --no-build -- seed-catalog
if ($LASTEXITCODE -ne 0) { Fail 'Catalog seed failed.' }

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    if (Test-Path (Join-Path $AppDir 'pubspec.yaml')) {
        Step 'Fetching Flutter packages'
        Push-Location $AppDir; flutter pub get; Pop-Location
    }
} else {
    Write-Host 'Flutter was not found: the API is ready, but install Flutter (https://docs.flutter.dev/get-started/install/windows) to run the app.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Setup complete.' -ForegroundColor Green
Write-Host "  Start the API:    .\scripts\start-api.ps1     (http://127.0.0.1:$ApiPort)"
Write-Host '  Run the tests:    .\scripts\test.ps1'
Write-Host '  Launch Android:   .\scripts\run-android.ps1'
