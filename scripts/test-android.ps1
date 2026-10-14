<#
.SYNOPSIS
  Runs the native Android journeys (integration_test) on an emulator/device against the local API and saves
  real screenshots to docs\evidence\screenshots. Each journey registers its own disposable account.

  journey_test            main path: register, plan, workout, food, themes, sign out/in
  journey_secondary_test  manual workout, save for later, no-data finish, plan pause/resume/skip/stop, name, deletion
  journey_device_test     OS reminders follow the plan; GPS measures a run (emulator only: positions are simulated)
  journey_upgrade_test    an install from before appearance became a device setting keeps its Light or Dark
  journey_coldstart_test  two runs on one install: an open workout, a food and an open run survive the process ending
  journey_plan_test       plan builder in two runs on one install: a template plan customised and activated offline
                          with a set recorded, a new process recovers them; rescheduling, a future edit, a resumed
                          own-plan draft as a rotation replacing the first plan, skip
  journey_food_test       goals, search, amount, log, reuse, barcode, manual fallback, restart. Needs the API started
                          with start-api.ps1 -FoodFixtures (recorded provider responses, not the live providers)
.PARAMETER Only
  Run just one journey, for example -Only journey_device_test.
#>
param([string]$Avd, [string]$ApiBase = "http://10.0.2.2:5131", [string]$Only)
. "$PSScriptRoot\common.ps1"
. "$PSScriptRoot\android-common.ps1"
Assert-Tool flutter 'Install Flutter: https://docs.flutter.dev/get-started/install/windows'
Assert-LocalApi $ApiBase
$device = Start-AndroidDevice $Avd
$appId = 'com.gohard.rebuild.debug'
$journeys = if ($Only) { @($Only) } else { 'journey_test', 'journey_secondary_test', 'journey_more_test', 'journey_offline_test', 'journey_device_test', 'journey_upgrade_test', 'journey_food_test', 'journey_coldstart_test', 'journey_plan_test' }
& $Adb -s $device shell input keyevent KEYCODE_HOME   # start from the home screen, whatever app was in front

Push-Location $AppDir
try {
    foreach ($journey in $journeys) {
        # A clean install, so a journey never starts from another run's signed-in state. Only this app's debug identity is touched.
        & $Adb -s $device uninstall $appId 2>$null | Out-Null
        $feeder = $null
        # A test cannot tap system permission dialogs, so for these journeys the app is installed first and the permissions granted.
        $grants = @{ journey_device_test = 'POST_NOTIFICATIONS', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'; journey_food_test = @('CAMERA') }[$journey]
        if ($grants) {
            Step "Building and installing the app to grant: $($grants -join ', ')"
            flutter build apk --debug --dart-define=GOHARD_API_BASE=$ApiBase | Out-Null
            if ($LASTEXITCODE -ne 0) { Fail 'The debug build failed.' }
            & $Adb -s $device install -r 'build\app\outputs\flutter-apk\app-debug.apk' | Out-Null
            foreach ($p in $grants) { & $Adb -s $device shell pm grant $appId "android.permission.$p" }
        }
        if ($journey -eq 'journey_device_test') {
            if ($device -notmatch '^emulator-') { Fail 'journey_device_test simulates GPS positions and so needs an emulator.' }
            # Simulated walk north, about 8 m every 2 s, through Android's test location provider
            # (the emulator console's "geo fix" does not move the position on this image).
            & $Adb -s $device shell appops set com.android.shell android:mock_location allow
            & $Adb -s $device shell cmd location providers add-test-provider gps 2>$null | Out-Null
            & $Adb -s $device shell cmd location providers set-test-provider-enabled gps true | Out-Null
            $feeder = Start-Job -ArgumentList $Adb, $device -ScriptBlock {
                param($adb, $device)
                for ($i = 1; $i -le 400; $i++) {
                    $lat = [string]::Format([cultureinfo]::InvariantCulture, '{0:F6}', 45.5017 + $i * 0.00007)
                    & $adb -s $device shell cmd location providers set-test-provider-location gps --location "$lat,-73.5673" --accuracy 5 | Out-Null
                    Start-Sleep -Seconds 2
                }
            }
        }
        if ($journey -in 'journey_offline_test', 'journey_plan_test') {
            # The journey prints GOHARD_NET:off / GOHARD_NET:on; this switches the device's Wi-Fi and mobile data to match,
            # so the middle of the journey is genuinely offline. The connection is always restored afterwards.
            & $Adb -s $device logcat -c
            $feeder = Start-Job -ArgumentList $Adb, $device -ScriptBlock {
                param($adb, $device)
                & $adb -s $device logcat -s flutter:I | ForEach-Object {
                    if ($_ -match 'GOHARD_NET:(off|on)') {
                        $state = if ($Matches[1] -eq 'off') { 'disable' } else { 'enable' }
                        & $adb -s $device shell svc wifi $state
                        & $adb -s $device shell svc data $state
                    }
                }
            }
        }
        # Captures land in a new folder of their own (git-ignored, under build\). Nothing else has those files open,
        # so writing them cannot collide with a git status that is hashing the tracked evidence folder.
        $shots = Join-Path $AppDir "build\journey-shots\$journey-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Force $shots | Out-Null
        $env:GOHARD_SHOT_DIR = $shots
        try {
            Step "Native journey '$journey' on $device against $ApiBase"
            # The cold-start journey runs twice on one install. The Flutter tool uninstalls the app when a run ends,
            # which would wipe what the first run saved, so the first run leaves the app in place and its process is
            # killed here instead. The second run is then a new process that can only show what was saved on the device.
            $phases = if ($journey -in 'journey_coldstart_test', 'journey_plan_test') { '1', '2' } else { @('') }
            foreach ($phase in $phases) {
                if ($phase) { Step "  phase $phase of 2$(if ($phase -eq '2') { ' (new process, same install)' })" }
                $keep = if ($phase -eq '1') { '--keep-app-running' } else { '--no-keep-app-running' }
                flutter drive --driver=test_driver/integration_test.dart --target=integration_test/$journey.dart -d $device --dart-define=GOHARD_API_BASE=$ApiBase --dart-define=GOHARD_PHASE=$phase $keep
                if ($LASTEXITCODE -ne 0) { Fail "The native journey '$journey'$(if ($phase) { " (phase $phase)" }) failed." }
                if ($phase -eq '1') {
                    & $Adb -s $device shell am force-stop $appId
                    & $Adb forward --remove-all   # the first run's debugger port must not be mistaken for the new process's
                    Start-Sleep -Seconds 2
                    if (& $Adb -s $device shell pidof $appId) { Fail 'The app process is still running after force-stop, so the next phase would not be a cold start.' }
                    if (-not ((& $Adb -s $device shell pm list packages $appId) -match [regex]::Escape($appId))) { Fail 'The app is no longer installed after phase 1, so its saved data is gone.' }
                    Write-Host '    app process ended (force-stop); the install and its data are kept' -ForegroundColor DarkGray
                }
            }
            # Only a journey that passed publishes evidence. Each capture is copied over the tracked one and read
            # back; a file another program holds for a moment is retried, and one that stays locked fails the run
            # by name rather than leaving an older picture in its place.
            $captured = @(Get-ChildItem $shots -Filter *.png)
            if ($captured.Count -eq 0) { Fail "The native journey '$journey' passed but saved no screenshots." }
            foreach ($shot in $captured) {
                $target = Join-Path $Root "docs\evidence\screenshots\$($shot.Name)"
                $copied = $false
                for ($try = 1; $try -le 40 -and -not $copied; $try++) {
                    try {
                        Copy-Item $shot.FullName $target -Force -ErrorAction Stop
                        $copied = (Get-FileHash $target).Hash -eq (Get-FileHash $shot.FullName).Hash
                    } catch { Start-Sleep -Milliseconds 500 }
                }
                if (-not $copied) { Fail "The screenshot $($shot.Name) could not be written to docs\evidence\screenshots (still locked after 20 seconds). The fresh capture is in $shots." }
            }
            Write-Host "    $($captured.Count) fresh screenshots from '$journey' copied to docs\evidence\screenshots" -ForegroundColor DarkGray
        } finally {
            if ($feeder) {
                Stop-Job $feeder; Remove-Job $feeder
                if ($journey -eq 'journey_device_test') { & $Adb -s $device shell cmd location providers remove-test-provider gps 2>$null | Out-Null }   # give the emulator its own position back
                if ($journey -in 'journey_offline_test', 'journey_plan_test') { & $Adb -s $device shell svc wifi enable; & $Adb -s $device shell svc data enable }
            }
        }
    }
} finally { Pop-Location }
Write-Host "Native journeys passed. Screenshots: $(Join-Path $Root 'docs\evidence\screenshots')" -ForegroundColor Green
