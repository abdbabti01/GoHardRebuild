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
  journey_progress_test   weekly goals, an exercise trend and last week's recap in two runs on one install: a goal saved
                          offline survives a new process and reaches the account; last week keeps its own goal (not default)
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
        $gpsFeed = $null
        # journey_move_test: SIMULATED steps (the emulator has no step counter), labelled on screen.
        [string[]]$simSteps = if ($journey -in 'journey_move_test', 'journey_ux_test', 'journey_today_water_test') { '--dart-define=GOHARD_SIM_STEPS=true' } else { @() }
        if ($journey -in 'journey_move_test', 'journey_ux_test') {
            if ($device -notmatch '^emulator-') { Fail 'journey_move_test simulates GPS positions and so needs an emulator.' }
            # SIMULATED GPS: a run north at about 3.5 m/s, one position a second, through Android's test location provider.
            & $Adb -s $device shell appops set com.android.shell android:mock_location allow
            try { & $Adb -s $device shell cmd location providers add-test-provider gps 2>$null | Out-Null } catch { }   # left over from an earlier run: fine
            & $Adb -s $device shell cmd location providers set-test-provider-enabled gps true | Out-Null
            $gpsFeed = Start-Job -ArgumentList $Adb, $device -ScriptBlock {
                param($adb, $device)
                for ($i = 1; $i -le 1800; $i++) {
                    $lat = [string]::Format([cultureinfo]::InvariantCulture, '{0:F7}', 46.8000 + $i * 0.0000314)
                    & $adb -s $device shell cmd location providers set-test-provider-location gps --location "$lat,-71.2200" --accuracy 5 | Out-Null
                    Start-Sleep -Milliseconds 1000
                }
            }
        }
        # A test cannot tap system permission dialogs, so for these journeys the app is installed first and the permissions granted.
        $location = 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'
        $grants = @{
            journey_device_test = @('POST_NOTIFICATIONS') + $location; journey_food_test = @('CAMERA'); journey_runwalk_test = @('POST_NOTIFICATIONS') + $location
            journey_move_test = @('POST_NOTIFICATIONS') + $location; journey_ux_test = @('POST_NOTIFICATIONS') + $location
            # These start a run or walk on the way (Run / Walk asks for location when Start is pressed).
            journey_coldstart_test = $location; journey_today_panels_test = $location; journey_appwide_test = $location
        }[$journey]
        if ($grants) {
            Step "Building and installing the app to grant: $($grants -join ', ')"
            # Only the device's ABI: the all-ABI debug APK (with Google Maps) no longer fits the emulator's free space twice over.
            $abi = (& $Adb -s $device shell getprop ro.product.cpu.abi).Trim()
            $platform = @{ 'x86_64' = 'android-x64'; 'arm64-v8a' = 'android-arm64'; 'armeabi-v7a' = 'android-arm' }[$abi]
            flutter build apk --debug --target-platform $platform --dart-define=GOHARD_API_BASE=$ApiBase $simSteps | Out-Null
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
        if ($journey -eq 'journey_runwalk_test') {
            if ($device -notmatch '^emulator-') { Fail 'journey_runwalk_test simulates GPS positions and so needs an emulator.' }
            # SIMULATED GPS: a walk north at about 1.4 m/s, one position a second, through Android's test location provider,
            # so the real geolocator stream and its foreground service are used. It runs through both phases.
            & $Adb -s $device shell appops set com.android.shell android:mock_location allow
            & $Adb -s $device shell cmd location providers add-test-provider gps 2>$null | Out-Null
            & $Adb -s $device shell cmd location providers set-test-provider-enabled gps true | Out-Null
            $gpsFeed = Start-Job -ArgumentList $Adb, $device -ScriptBlock {
                param($adb, $device)
                for ($i = 1; $i -le 1800; $i++) {
                    $lat = [string]::Format([cultureinfo]::InvariantCulture, '{0:F7}', 46.8000 + $i * 0.0000126)
                    & $adb -s $device shell cmd location providers set-test-provider-location gps --location "$lat,-71.2200" --accuracy 5 | Out-Null
                    Start-Sleep -Milliseconds 1000
                }
            }
            # The journey prints markers; this answers them: captures (adb screencap, so the map's platform view is in
            # them), the screen recording, Home / screen off and back, and the network off and on.
            $runShots = Join-Path $AppDir "build\journey-shots\runwalk-host-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            New-Item -ItemType Directory -Force $runShots | Out-Null
            & $Adb -s $device logcat -c
            $feeder = Start-Job -ArgumentList $Adb, $device, $runShots, $appId -ScriptBlock {
                param($adb, $device, $out, $appId)
                & $adb -s $device logcat -s flutter:I | ForEach-Object {
                    if ($_ -match 'GOHARD_SHOT:([\w-]+)') {
                        & $adb -s $device shell screencap -p "/sdcard/$($Matches[1]).png"
                        & $adb -s $device pull "/sdcard/$($Matches[1]).png" (Join-Path $out "$($Matches[1]).png") | Out-Null
                    } elseif ($_ -match 'GOHARD_REC:start:([\w-]+)') {
                        Start-Process -FilePath $adb -ArgumentList '-s', $device, 'shell', 'screenrecord', '--time-limit', '170', "/sdcard/$($Matches[1]).mp4" -WindowStyle Hidden
                        Set-Content (Join-Path $out 'recording.txt') $Matches[1]
                    } elseif ($_ -match 'GOHARD_REC:stop') {
                        & $adb -s $device shell pkill -INT screenrecord
                        Start-Sleep -Seconds 3
                        $name = Get-Content (Join-Path $out 'recording.txt')
                        & $adb -s $device pull "/sdcard/$name.mp4" (Join-Path $out "$name.mp4") | Out-Null
                    } elseif ($_ -match 'GOHARD_BG:home') {
                        & $adb -s $device shell input keyevent KEYCODE_HOME
                        Start-Sleep -Seconds 6
                        & $adb -s $device shell cmd statusbar expand-notifications
                        Start-Sleep -Seconds 2
                        & $adb -s $device shell screencap -p /sdcard/runwalk-07-notification.png
                        & $adb -s $device pull /sdcard/runwalk-07-notification.png (Join-Path $out 'runwalk-07-notification.png') | Out-Null
                        & $adb -s $device shell cmd statusbar collapse
                        (& $adb -s $device shell dumpsys notification --noredact) -match 'GoHard is recording|android.title=' | Set-Content (Join-Path $out 'notification.txt')
                        Start-Sleep -Seconds 8
                        & $adb -s $device shell am start -n "$appId/com.gohard.gohard_rebuild.MainActivity" | Out-Null
                    } elseif ($_ -match 'GOHARD_BG:lock') {
                        & $adb -s $device shell input keyevent KEYCODE_SLEEP
                        Start-Sleep -Seconds 18
                        & $adb -s $device shell input keyevent KEYCODE_WAKEUP
                        & $adb -s $device shell wm dismiss-keyguard
                    } elseif ($_ -match 'GOHARD_NET:(off|on)') {
                        $state = if ($Matches[1] -eq 'off') { 'disable' } else { 'enable' }
                        & $adb -s $device shell svc wifi $state
                        & $adb -s $device shell svc data $state
                    }
                }
            }
        }
        if ($journey -in 'journey_offline_test', 'journey_plan_test', 'journey_water_test') {
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
        if ($journey -in 'journey_workout_panel_test', 'journey_progress_test', 'journey_body_test') {
            # The journey prints GOHARD_REC:start:<name> / GOHARD_REC:stop; this records the screen in between.
            # journey_progress_test also prints GOHARD_NET:off / on, which switches Wi-Fi and mobile data to match.
            & $Adb -s $device logcat -c
            $feeder = Start-Job -ArgumentList $Adb, $device, $shots -ScriptBlock {
                param($adb, $device, $out)
                & $adb -s $device logcat -s flutter:I | ForEach-Object {
                    if ($_ -match 'GOHARD_REC:start:([\w-]+)') {
                        Start-Process -FilePath $adb -ArgumentList '-s', $device, 'shell', 'screenrecord', '--time-limit', '170', "/sdcard/$($Matches[1]).mp4" -WindowStyle Hidden
                        Set-Content (Join-Path $out 'recording.txt') $Matches[1]
                    } elseif ($_ -match 'GOHARD_REC:stop') {
                        & $adb -s $device shell pkill -INT screenrecord
                        Start-Sleep -Seconds 3
                        $name = Get-Content (Join-Path $out 'recording.txt')
                        & $adb -s $device pull "/sdcard/$name.mp4" (Join-Path $out "$name.mp4") | Out-Null
                    } elseif ($_ -match 'GOHARD_NET:(off|on)') {
                        $state = if ($Matches[1] -eq 'off') { 'disable' } else { 'enable' }
                        & $adb -s $device shell svc wifi $state
                        & $adb -s $device shell svc data $state
                    }
                }
            }
        }
        try {
            Step "Native journey '$journey' on $device against $ApiBase"
            # The cold-start journey runs twice on one install. The Flutter tool uninstalls the app when a run ends,
            # which would wipe what the first run saved, so the first run leaves the app in place and its process is
            # killed here instead. The second run is then a new process that can only show what was saved on the device.
            $phases = if ($journey -in 'journey_coldstart_test', 'journey_plan_test', 'journey_water_test', 'journey_runwalk_test', 'journey_move_test', 'journey_workout_panel_test', 'journey_progress_test', 'journey_body_test') { '1', '2' } else { @('') }
            foreach ($phase in $phases) {
                if ($phase) { Step "  phase $phase of 2$(if ($phase -eq '2') { ' (new process, same install)' })" }
                $keep = if ($phase -eq '1') { '--keep-app-running' } else { '--no-keep-app-running' }
                # journey_move_test reads its phase from what phase 1 left on the phone, so both phases are one build and
                # phase 2 needs no reinstall (the emulator has no room for a second copy of the app).
                [string[]]$phaseDefine = if ($journey -eq 'journey_move_test') { @() } else { "--dart-define=GOHARD_PHASE=$phase" }
                flutter drive --driver=test_driver/integration_test.dart --target=integration_test/$journey.dart -d $device --dart-define=GOHARD_API_BASE=$ApiBase $phaseDefine $simSteps $keep
                if ($LASTEXITCODE -ne 0) { Fail "The native journey '$journey'$(if ($phase) { " (phase $phase)" }) failed." }
                if ($phase -eq '1') {
                    & $Adb -s $device shell am force-stop $appId
                    & $Adb forward --remove-all   # the first run's debugger port must not be mistaken for the new process's
                    Start-Sleep -Seconds 2
                    if (& $Adb -s $device shell pidof $appId) { Fail 'The app process is still running after force-stop, so the next phase would not be a cold start.' }
                    if (-not ((& $Adb -s $device shell pm list packages $appId) -match [regex]::Escape($appId))) { Fail 'The app is no longer installed after phase 1, so its saved data is gone.' }
                    Write-Host '    app process ended (force-stop); the install and its data are kept' -ForegroundColor DarkGray
                    if ($journey -in 'journey_move_test', 'journey_ux_test') {
                        # The phone restarts between the phases: it frees the emulator's storage for phase 2's install, and
                        # the recording must come back Interrupted after a real restart.
                        & $Adb -s $device reboot
                        & $Adb -s $device wait-for-device
                        for ($w = 0; $w -lt 60 -and (& $Adb -s $device shell getprop sys.boot_completed).Trim() -ne '1'; $w++) { Start-Sleep -Seconds 3 }
                        & $Adb forward --remove-all
                        Write-Host '    the emulator restarted between the phases' -ForegroundColor DarkGray
                    }
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
            foreach ($f in Get-ChildItem $shots -Filter *.mp4) { Copy-Item $f.FullName (Join-Path $Root "docs\evidence\recordings\$($f.Name)") -Force }
            if ($journey -eq 'journey_runwalk_test') {
                Start-Sleep -Seconds 4   # the last host capture
                foreach ($f in Get-ChildItem $runShots -Include *.png, *.mp4, *.txt -Recurse) {
                    $dest = if ($f.Extension -eq '.mp4') { "docs\evidence\recordings\$($f.Name)" } elseif ($f.Extension -eq '.txt') { "docs\evidence\runwalk-$($f.Name)" } else { "docs\evidence\screenshots\$($f.Name)" }
                    Copy-Item $f.FullName (Join-Path $Root $dest) -Force
                }
                Write-Host "    host captures from '$journey' copied (screenshots, recording, notification check)" -ForegroundColor DarkGray
            }
        } finally {
            if ($gpsFeed) {
                Stop-Job $gpsFeed; Remove-Job $gpsFeed; $gpsFeed = $null
                & $Adb -s $device shell cmd location providers remove-test-provider gps 2>$null | Out-Null
            }
            if ($feeder) {
                Stop-Job $feeder; Remove-Job $feeder
                if ($journey -eq 'journey_runwalk_test') { & $Adb -s $device shell svc wifi enable; & $Adb -s $device shell svc data enable }
                if ($journey -eq 'journey_device_test') { & $Adb -s $device shell cmd location providers remove-test-provider gps 2>$null | Out-Null }   # give the emulator its own position back
                if ($journey -in 'journey_offline_test', 'journey_plan_test', 'journey_water_test', 'journey_progress_test') { & $Adb -s $device shell svc wifi enable; & $Adb -s $device shell svc data enable }
            }
        }
    }
} finally { Pop-Location }
Write-Host "Native journeys passed. Screenshots: $(Join-Path $Root 'docs\evidence\screenshots')" -ForegroundColor Green
