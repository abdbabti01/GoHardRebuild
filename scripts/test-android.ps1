<#
.SYNOPSIS
  Runs the native Android journey (integration_test) on an emulator/device against the local API and saves
  real screenshots to docs\evidence\screenshots. Registers a disposable account on each run.
#>
param([string]$Avd, [string]$ApiBase = "http://10.0.2.2:5131")
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\android-common.ps1"
Assert-Tool flutter 'Install Flutter: https://docs.flutter.dev/get-started/install/windows'
Assert-LocalApi $ApiBase
$device = Start-AndroidDevice $Avd
# A clean install, so the journey never starts from another run's signed-in state. Only this app's debug identity is touched.
& $Adb -s $device uninstall com.gohard.rebuild.debug 2>$null | Out-Null
Step "Native journey on $device against $ApiBase"
Push-Location $AppDir
try {
    flutter drive --driver=test_driver/integration_test.dart --target=integration_test/journey_test.dart -d $device --dart-define=GOHARD_API_BASE=$ApiBase
    if ($LASTEXITCODE -ne 0) { Fail 'The native journey failed.' }
} finally { Pop-Location }
Write-Host "Native journey passed. Screenshots: $(Join-Path $Root 'docs\evidence\screenshots')" -ForegroundColor Green
