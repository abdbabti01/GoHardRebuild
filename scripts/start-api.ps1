<#
.SYNOPSIS
  Starts the GoHard rebuild API. It only reads schema readiness; run setup.ps1 to migrate.
.PARAMETER Lan
  Listen on all interfaces so a physical phone on the same network can reach the API.
.PARAMETER FoodFixtures
  Answer food search and barcode lookups, and weather and city lookups, from recorded provider responses instead of
  Open Food Facts, USDA and Open-Meteo.
  For local development and the native journeys. Without it, barcode lookup calls Open Food Facts for real, and
  search works only when a USDA key is configured (FoodData:UsdaApiKey in appsettings.Local.json, or the
  GOHARD_FoodData__UsdaApiKey environment variable).
#>
param([switch]$Lan, [switch]$FoodFixtures)
. "$PSScriptRoot\common.ps1"
Assert-DotNet10
if (-not (Test-Path $LocalConfig)) { Fail 'Local configuration is missing. Run .\scripts\setup.ps1 first.' }
if (Test-PortInUse $ApiPort) { Fail "Port $ApiPort is already in use. Is the API already running?" }
$bind = if ($Lan) { "http://0.0.0.0:$ApiPort" } else { "http://127.0.0.1:$ApiPort" }
Step "Starting API on $bind (readiness: $bind/health/ready)"
$env:ASPNETCORE_ENVIRONMENT = 'Development'
$fixtures = $null
if ($FoodFixtures) {
    if (Test-PortInUse 5132) { Fail 'Port 5132 (recorded food responses) is already in use.' }
    Step 'Food lookups are answered from recorded provider responses (http://localhost:5132), not the live providers'
    $fixtures = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'food-fixtures.ps1') -WindowStyle Hidden -PassThru
    $env:GOHARD_FoodData__UsdaApiKey = 'recorded-responses'
    $env:GOHARD_FoodData__UsdaBaseUrl = 'http://localhost:5132/usda/'
    $env:GOHARD_FoodData__OpenFoodFactsBaseUrl = 'http://localhost:5132/off/'
    $env:GOHARD_Weather__ForecastBaseUrl = 'http://localhost:5132/openmeteo/v1/'
    $env:GOHARD_Weather__GeocodingBaseUrl = 'http://localhost:5132/openmeteo-geo/v1/'
}
try {
    dotnet run --project $ApiProject -- --urls $bind
} finally { if ($fixtures) { Stop-Process -Id $fixtures.Id -ErrorAction SilentlyContinue } }
