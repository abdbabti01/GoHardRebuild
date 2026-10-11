<#
.SYNOPSIS
  Runs every automated check for the GoHard rebuild. Fails (never skips) when required infrastructure is missing.
  API tests run on a disposable PostgreSQL container (Testcontainers), never on the development database.
.PARAMETER SkipApp
  Only run the API checks.
.PARAMETER SkipApi
  Only run the Flutter checks.
#>
param([switch]$SkipApp, [switch]$SkipApi)
. "$PSScriptRoot\common.ps1"

if (-not $SkipApi) {
    Assert-DotNet10
    Assert-Docker   # required: PostgreSQL behaviour is only proven on real PostgreSQL
    Step 'API: build (warnings are errors)'
    # Release configuration: its output is separate from the Debug build a running start-api.ps1 keeps locked.
    dotnet build (Join-Path $Root 'api') -c Release --nologo -v q
    if ($LASTEXITCODE -ne 0) { Fail 'API build failed.' }
    Step 'API: tests on disposable PostgreSQL'
    dotnet test (Join-Path $Root 'api') -c Release --no-build --nologo
    if ($LASTEXITCODE -ne 0) { Fail 'API tests failed.' }
    Step 'API: release publish'
    dotnet publish $ApiProject -c Release -o (Join-Path $Root 'publish\api') --nologo -v q
    if ($LASTEXITCODE -ne 0) { Fail 'API publish failed.' }
}

if (-not $SkipApp) {
    Assert-Tool flutter 'Install Flutter: https://docs.flutter.dev/get-started/install/windows'
    Push-Location $AppDir
    try {
        Step 'App: packages and generated database code'
        flutter pub get
        if ($LASTEXITCODE -ne 0) { Fail 'flutter pub get failed.' }
        dart run build_runner build --delete-conflicting-outputs
        if ($LASTEXITCODE -ne 0) { Fail 'Code generation failed.' }
        Step 'App: static analysis'
        flutter analyze
        if ($LASTEXITCODE -ne 0) { Fail 'flutter analyze reported issues.' }
        Step 'App: unit, real-Drift and widget tests'
        flutter test
        if ($LASTEXITCODE -ne 0) { Fail 'Flutter tests failed.' }
    } finally { Pop-Location }
}
Write-Host 'All checks passed.' -ForegroundColor Green
