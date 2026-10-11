<#
.SYNOPSIS
  Launches the GoHard rebuild app on an Android emulator or device against the local development API.
.PARAMETER Avd
  Emulator name to start when no device is connected (default: the first one found).
.PARAMETER ApiBase
  API origin as the device sees it. The emulator reaches this PC at 10.0.2.2. For a physical phone use
  http://<this-pc-lan-ip>:5131 and start the API with .\scripts\start-api.ps1 -Lan.
#>
param([string]$Avd, [string]$ApiBase = "http://10.0.2.2:5131")
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\android-common.ps1"
Assert-Tool flutter 'Install Flutter: https://docs.flutter.dev/get-started/install/windows'
Assert-LocalApi $ApiBase
$device = Start-AndroidDevice $Avd
Step "Running on $device against $ApiBase (debug identity com.gohard.rebuild.debug; it does not replace the original GoHard app)"
Push-Location $AppDir
try { flutter run -d $device --dart-define=GOHARD_API_BASE=$ApiBase } finally { Pop-Location }
