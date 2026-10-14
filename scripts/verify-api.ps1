<#
.SYNOPSIS
  Verifies a running GoHard rebuild API end to end: readiness, client/backend contract compatibility,
  registration, sign-in, an idempotent write, reading it back, nutrition goals (set, kept by an older payload,
  cleared), a reusable food, food lookup and weather/city lookup where the server declares them, and account deletion (so no test data is left).
  The food lookup checks go through whatever providers that server is configured with. Against a deployed server
  they are the live provider check; against a local API started with -FoodFixtures they only exercise recordings.
  Safe to run against the local API or the hosted TESTING API. It prints no tokens or passwords.
.PARAMETER BaseUrl
  API origin, for example http://127.0.0.1:5131 or https://<your-service>.up.railway.app
#>
param([Parameter(Mandatory)][string]$BaseUrl)
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$failed = $false
function Check($name, [scriptblock]$test) {
    try { $detail = & $test; Write-Host "  PASS  $name$(if ($detail) { " - $detail" })" -ForegroundColor Green }
    catch { $script:failed = $true; Write-Host "  FAIL  $name - $($_.Exception.Message)" -ForegroundColor Red }
}
function Api($method, $path, $body, $token) {
    $headers = @{}; if ($token) { $headers.Authorization = "Bearer $token" }
    $args = @{ Method = $method; Uri = "$BaseUrl$path"; Headers = $headers; TimeoutSec = 30 }
    if ($null -ne $body) { $args.Body = ($body | ConvertTo-Json -Depth 8); $args.ContentType = 'application/json' }
    Invoke-RestMethod @args
}

Write-Host "Verifying $BaseUrl"
$appContract = [int]((Select-String -Path (Join-Path $PSScriptRoot '..\app\lib\core\config.dart') -Pattern 'contractVersion = (\d+)').Matches[0].Groups[1].Value)
$email = "verify-$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())@example.test"
$password = [Guid]::NewGuid().ToString('N')   # random, used once, never printed
$today = (Get-Date).ToString('yyyy-MM-dd')

Check 'Uses HTTPS (required by the iOS release build)' {
    if ($BaseUrl -match '^https://') { 'yes' } elseif ($BaseUrl -match '^http://(127\.0\.0\.1|localhost)') { 'local HTTP, fine for local checks only' } else { throw 'not HTTPS' }
}
Check 'Readiness (schema migrated, database reachable)' { (Api GET '/health/ready').status }
Check 'Client/backend contract compatibility' {
    $c = Api GET '/api/v1/capabilities'
    if ($c.contractVersion -ne $appContract -or $c.minimumClientContract -gt $appContract) { throw "app speaks contract $appContract, server offers $($c.contractVersion) (minimum $($c.minimumClientContract))" }
    "contract $appContract, $($c.capabilities.Count) capabilities"
}
$token = $null
Check 'Registration' { $r = Api POST '/api/v1/auth/register' @{ email = $email; password = $password; displayName = 'API Verify' }; $script:token = $r.accessToken; 'account created' }
Check 'Sign-in with the same credentials' { $r = Api POST '/api/v1/auth/login' @{ email = $email; password = $password }; $script:token = $r.accessToken; 'token issued' }
Check 'Wrong password is refused' {
    try { Api POST '/api/v1/auth/login' @{ email = $email; password = 'definitely-wrong' } | Out-Null; throw 'accepted a wrong password' }
    catch { if ($_.Exception.Response.StatusCode.value__ -ne 401) { throw } ; '401' }
}
Check 'Protected data needs a token' {
    try { Api GET '/api/v1/me' | Out-Null; throw 'served /me without a token' } catch { if ($_.Exception.Response.StatusCode.value__ -ne 401) { throw }; '401' }
}
$entry = @{ operationId = [Guid]::NewGuid(); entryId = [Guid]::NewGuid(); dayKey = $today; meal = 'Snack'; name = 'Verification apple'; amountDescription = '1'; macros = @{ calories = 0; protein = $null; carbs = $null; fat = $null } }
Check 'Saving data, and a retry does not duplicate it' {
    $a = Api POST '/api/v1/food-entries' $entry $token
    $b = Api POST '/api/v1/food-entries' $entry $token
    $list = Api GET "/api/v1/food-entries?date=$today" $null $token
    if ($a.status -ne 'accepted' -or $b.data.id -ne $a.data.id -or @($list).Count -ne 1) { throw 'duplicate or rejected' }
    if ($null -ne $list[0].macros.protein -or $list[0].macros.calories -ne 0) { throw 'unknown/zero nutrients were not preserved' }
    'one entry; unknown stays unknown, zero stays zero'
}
$capabilities = @()
Check 'Declared capabilities' { $script:capabilities = @((Api GET '/api/v1/capabilities').capabilities); ($capabilities | Where-Object { $_ -match '^(food|profile)\.' }) -join ', ' }
if ($capabilities -contains 'profile.nutrition-goals') {
    Check 'Nutrition goals: set, kept by an app that does not know them, cleared only on purpose' {
        $me = Api GET '/api/v1/me' $null $token
        $base = @{ displayName = $me.displayName; appearance = $me.appearance; loadUnit = $me.loadUnit; remindersEnabled = $me.remindersEnabled; reminderLocalTime = $me.reminderLocalTime }
        $set = Api PUT '/api/v1/me' ($base + @{ operationId = [Guid]::NewGuid(); expectedRevision = $me.revision; calorieGoal = 2200; proteinGoal = 140 }) $token
        if ($set.data.calorieGoal -ne 2200 -or $set.data.proteinGoal -ne 140) { throw 'goals were not saved' }
        $old = Api PUT '/api/v1/me' ($base + @{ operationId = [Guid]::NewGuid(); expectedRevision = $set.revision }) $token      # no goal fields at all
        if ((Api GET '/api/v1/me' $null $token).calorieGoal -ne 2200) { throw 'an older payload erased the goals' }
        $cleared = Api PUT '/api/v1/me' ($base + @{ operationId = [Guid]::NewGuid(); expectedRevision = $old.revision; calorieGoal = $null; proteinGoal = $null }) $token
        $after = Api GET '/api/v1/me' $null $token
        if ($null -ne $after.calorieGoal -or $null -ne $after.proteinGoal) { throw 'goals were not cleared' }
        'saved, read back, preserved, cleared'
    }
} else { Write-Host '  SKIP  Nutrition goals - this server does not declare profile.nutrition-goals' -ForegroundColor Yellow }
if ($capabilities -contains 'food.saved') {
    Check 'A reusable food is saved without logging anything' {
        $id = [Guid]::NewGuid()
        $r = Api PUT "/api/v1/saved-foods/$id" @{ operationId = [Guid]::NewGuid(); expectedRevision = 0; isFavourite = $true; item = @{ source = 'user'; sourceId = "$id"; name = 'Verification oats'; basis = 'serving'; nutrients = @{ calories = 420; protein = $null; carbs = $null; fat = 0 } } } $token
        $s = Api GET '/api/v1/sync/snapshot' $null $token
        if ($r.status -ne 'accepted' -or @($s.savedFoods).Count -ne 1 -or @($s.foodEntries).Count -ne 1) { throw 'saved food missing, or it changed the journal' }
        'one saved food; the journal is unchanged'
    }
}
function Lookup($path) {
    try { @{ ok = $true; data = (Api GET $path $null $token) } }
    catch { @{ ok = $false; status = $_.Exception.Response.StatusCode.value__; code = $(try { ($_.ErrorDetails.Message | ConvertFrom-Json).code } catch { $null }) } }
}
if ($capabilities -contains 'food.barcode') {
    Check 'Barcode lookup through the server''s provider (3017620422003)' {
        $r = Lookup '/api/v1/foods/barcode/3017620422003'
        if (-not $r.ok) { throw "lookup failed: HTTP $($r.status) $($r.code)" }
        if ($r.data.item.source -ne 'off' -or $r.data.item.barcode -ne '3017620422003' -or -not $r.data.item.name) { throw 'unexpected product' }
        "$($r.data.item.name): $($r.data.item.nutrients.calories) kcal per $($r.data.item.basis)"
    }
    Check 'An unknown barcode is reported as not found, not invented' {
        $r = Lookup '/api/v1/foods/barcode/00000017'
        if ($r.ok -or $r.status -ne 404) { throw "expected 404, got $(if ($r.ok) { 'a product' } else { $r.status })" }
        '404 NOT_FOUND'
    }
}
if ($capabilities -contains 'food.search') {
    Check 'Food search through the server''s provider (chicken breast)' {
        $r = Lookup '/api/v1/foods/search?q=chicken%20breast'
        if (-not $r.ok) { throw "search failed: HTTP $($r.status) $($r.code)" }
        if (@($r.data.results).Count -lt 1 -or $r.data.results[0].source -ne 'usda') { throw 'no USDA results' }
        "$(@($r.data.results).Count) results, first: $($r.data.results[0].name)"
    }
} else { Write-Host '  NOT CONFIGURED  Food search - the server has no USDA key (set GOHARD_FoodData__UsdaApiKey), so search is not declared and was not checked' -ForegroundColor Yellow }
if ($capabilities -contains 'weather.current') {
    Check 'Current weather through the server''s provider (a coarse point near Quebec City)' {
        $r = Lookup '/api/v1/weather/current?lat=46.81&lon=-71.21'
        if (-not $r.ok) { throw "weather failed: HTTP $($r.status) $($r.code)" }
        $w = $r.data
        if ($w.source -notin 'open-meteo','met.no' -or $w.family -notin 'clear','cloudy','fog','rain','snow','storm','unknown' -or $w.latitude -ne 46.8 -or $w.longitude -ne -71.2) { throw 'unexpected weather contract' }
        $age = ([DateTime]::UtcNow - [DateTime]::Parse($w.validAtUtc).ToUniversalTime()).TotalMinutes
        if ($age -lt -20 -or $age -gt 90) { throw "conditions are $([int]$age) minutes old" }
        "$($w.source): $($w.family) ($($w.description)), isDay=$($w.isDay), valid $([int]$age) min ago, $($w.timezone)"
    }
    Check 'The fallback provider answers from this server (MET Norway, same coarse point)' {
        $r = Lookup '/api/v1/weather/current?lat=46.81&lon=-71.21&provider=met.no'
        if (-not $r.ok) { throw "MET Norway failed: HTTP $($r.status) $($r.code)" }
        $w = $r.data
        if ($w.source -ne 'met.no' -or $w.latitude -ne 46.8 -or $w.longitude -ne -71.2 -or $null -eq $w.code) { throw 'unexpected fallback shape' }
        $age = ([DateTime]::UtcNow - [DateTime]::Parse($w.validAtUtc).ToUniversalTime()).TotalMinutes
        if ($age -lt 0 -or $age -gt 60) { throw "the hour in progress should be under an hour old, got $([int]$age) minutes" }
        "$($w.source): $($w.family) ($($w.description), WMO $($w.code)), isDay=$($w.isDay), hour from $([DateTime]::Parse($w.validAtUtc).ToUniversalTime().ToString('HH:mm')) UTC"
    }
    Check 'City lookup tells namesakes apart (Paris)' {
        $r = Lookup '/api/v1/weather/places?q=Paris'
        if (-not $r.ok) { throw "places failed: HTTP $($r.status) $($r.code)" }
        $all = @($r.data.results)
        if ($all.Count -lt 2 -or -not $all[0].id) { throw 'expected several identified places' }
        ($all | Select-Object -First 3 | ForEach-Object { "$($_.name), $($_.admin1), $($_.country)" }) -join ' | '
    }
} else { Write-Host '  NOT DECLARED  Weather - this server does not declare weather.current (Weather:Enabled=false)' -ForegroundColor Yellow }
Check 'Exercise catalog is seeded' { $s = Api GET '/api/v1/sync/snapshot' $null $token; if ($s.catalog.Count -lt 1) { throw 'catalog is empty: run seed-catalog' }; "$($s.catalog.Count) movements" }
Check 'Cleanup: the verification account is deleted' {
    Api DELETE '/api/v1/account' @{ password = $password } $token | Out-Null
    try { Api GET '/api/v1/me' $null $token | Out-Null; throw 'token still works after deletion' } catch { if ($_.Exception.Response.StatusCode.value__ -ne 401) { throw }; 'no test data left behind' }
}
if ($failed) { Write-Host 'API verification FAILED.' -ForegroundColor Red; exit 1 }
Write-Host 'API verification passed.' -ForegroundColor Green
