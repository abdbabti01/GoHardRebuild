# Shared Android helpers. Dot-source after common.ps1.
$AndroidSdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$Adb        = Join-Path $AndroidSdk 'platform-tools\adb.exe'
$Emulator   = Join-Path $AndroidSdk 'emulator\emulator.exe'

function Get-AndroidDevice {
    if (-not (Test-Path $Adb)) { Fail "adb was not found under $AndroidSdk. Install the Android SDK platform-tools." }
    (& $Adb devices | Select-String '^(\S+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value }) | Select-Object -First 1
}

function Start-AndroidDevice([string]$Avd) {
    $device = Get-AndroidDevice
    if ($device) { return $device }
    if (-not (Test-Path $Emulator)) { Fail 'No Android device is connected and the emulator is not installed.' }
    if (-not $Avd) { $Avd = & $Emulator -list-avds | Select-Object -First 1 }
    if (-not $Avd) { Fail 'No Android device is connected and no emulator (AVD) exists. Create one in Android Studio > Device Manager.' }
    Step "Starting emulator '$Avd'"
    Start-Process -FilePath $Emulator -ArgumentList "-avd $Avd -no-snapshot-save -no-boot-anim" -WindowStyle Minimized
    $deadline = (Get-Date).AddMinutes(4)
    do {
        Start-Sleep -Seconds 4
        $device = Get-AndroidDevice
        $booted = if ($device) { (& $Adb -s $device shell getprop sys.boot_completed 2>$null) -match '1' } else { $false }
    } until ($booted -or (Get-Date) -gt $deadline)
    if (-not $booted) { Fail 'The emulator did not finish booting within 4 minutes.' }
    $device
}

function Assert-LocalApi([string]$ApiBase) {
    # Journeys create disposable accounts, so they may only ever run against a local development API.
    if ($ApiBase -notmatch '^http://(10\.0\.2\.2|127\.0\.0\.1|localhost|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+)(:\d+)?$') {
        Fail "Refusing to run against '$ApiBase'. Only a local development API origin is allowed."
    }
    try { $ready = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 "http://127.0.0.1:$ApiPort/health/ready" } catch { $ready = $null }
    if (-not $ready -or $ready.StatusCode -ne 200) { Fail "The API is not ready on port $ApiPort. Run .\scripts\start-api.ps1 in another window first." }
}
