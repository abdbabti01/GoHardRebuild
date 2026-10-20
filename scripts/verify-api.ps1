<#
.SYNOPSIS
  Verifies a running GoHard rebuild API end to end: readiness, client/backend contract compatibility,
  registration, sign-in, an idempotent write, reading it back, nutrition goals (set, kept by an older payload,
  cleared), a reusable food, food lookup and weather/city lookup where the server declares them, the plan builder (a custom
  exercise, a rotating plan, its first step started, finished and credited, a revision) where declared, one contextual
  Ask GoHard question where coach.ask is declared (five with -Coach; live model calls; reported as not configured otherwise), and account
  deletion (so no test data is left).
  The food lookup checks go through whatever providers that server is configured with. Against a deployed server
  they are the live provider check; against a local API started with -FoodFixtures they only exercise recordings.
  Safe to run against the local API or the hosted TESTING API. It prints no tokens or passwords.

  Cleanup: the account's email is printed and appended to scripts\.verify-accounts.log (git-ignored) before
  registration, its id right after. Deletion (DELETE /api/v1/account with the password, then /me and sign-in must
  answer 401) runs in a finally block, so it also runs after a failing check, an exception or Ctrl+C. It cannot run
  if the process is killed (Task Manager, closed window, power loss, a second Ctrl+C during cleanup): then the log
  names the account and scripts\delete-verify-account.ps1 removes it.
  Exit code: 0 all passed, 1 a check failed (account deleted), 2 cleanup failed (account left behind).
.PARAMETER BaseUrl
  API origin, for example http://127.0.0.1:5131 or https://<your-service>.up.railway.app
.PARAMETER Coach
  Where coach.ask is declared: five live Ask GoHard checks instead of one (split question, follow-up with history,
  exercise explanation, a proposal-inviting question, a workout that is not in the draft). COACH_BUSY / COACH_LIMIT
  are reported as BUSY and stop further coach calls without failing. Where coach.ask is absent: one call that
  checks the request shape is accepted (503 COACH_UNAVAILABLE), no model involved.
.PARAMETER FailAfter
  Debug: throw right after the check whose name starts with this text, to prove cleanup still runs.
#>
param([Parameter(Mandatory)][string]$BaseUrl, [switch]$Coach, [string]$FailAfter)
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$failed = $false
# Fixed on purpose so delete-verify-account.ps1 can remove a left-over account. Acceptable only because each email
# carries 64 random bits and the account is deleted at the end of the run; never reuse it anywhere else.
$password = 'verify password 1'
$log = Join-Path $PSScriptRoot '.verify-accounts.log'
$accountId = $null
function Redact([string]$text) {
    if ($script:token) { $text = $text.Replace($script:token, '<token>') }
    $text.Replace($password, '<password>') -replace 'Bearer\s+\S+', 'Bearer <redacted>'
}
function Record($outcome) { Add-Content -Path $log -Encoding UTF8 -Value "$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))  $BaseUrl  $email  id=$(if ($accountId) { $accountId } else { '?' })  $outcome" }
function Check($name, [scriptblock]$test) {
    try { $detail = & $test; Write-Host "  PASS  $name$(if ($detail) { " - $detail" })" -ForegroundColor Green }
    catch { $script:failed = $true; Write-Host "  FAIL  $name - $(Redact $_.Exception.Message)" -ForegroundColor Red }
    if ($FailAfter -and $name -like "$FailAfter*") { throw "simulated failure after '$name' (-FailAfter)" }
}
function Status($err) { try { [int]$err.Exception.Response.StatusCode } catch { 0 } }
function Api($method, $path, $body, $token) {
    $headers = @{}; if ($token) { $headers.Authorization = "Bearer $token" }
    $args = @{ Method = $method; Uri = "$BaseUrl$path"; Headers = $headers; TimeoutSec = 30 }
    # As UTF-8 bytes: PowerShell 5.1 would send a string body in the legacy codepage, so "–" or "…" (in model answers
    # sent back as history) became invalid UTF-8 and the API rightly answered 400.
    if ($null -ne $body) { $args.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 8)); $args.ContentType = 'application/json; charset=utf-8' }
    Invoke-RestMethod @args
}

Write-Host "Verifying $BaseUrl"
$appContract = [int]((Select-String -Path (Join-Path $PSScriptRoot '..\app\lib\core\config.dart') -Pattern 'contractVersion = (\d+)').Matches[0].Groups[1].Value)
$email = "verify-$([Guid]::NewGuid().ToString('N').Substring(0, 16))@example.test"
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
$registerAttempted = $false
try {   # everything from registration on: the finally block at the end deletes the account whatever happens
Write-Host "  Account: $email" -ForegroundColor Cyan
$registerAttempted = $true; Record 'registering'
Check 'Registration' {
    $r = Api POST '/api/v1/auth/register' @{ email = $email; password = $password; displayName = 'API Verify' }
    $script:token = $r.accessToken; $script:accountId = $r.profile.userId; Record 'registered'
    "account created, id $accountId"
}
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
if ($capabilities -contains 'exercises.load-increment') {
    Check 'Weight increment: saved once under a retry, revision-checked, cleared only on purpose' {
        $op = [Guid]::NewGuid()
        $set = Api PUT '/api/v1/exercise-increments/bench-press' @{ operationId = $op; expectedRevision = 0; incrementKg = 2.5 } $token
        $retry = Api PUT '/api/v1/exercise-increments/bench-press' @{ operationId = $op; expectedRevision = 0; incrementKg = 2.5 } $token
        if ($set.status -ne 'accepted' -or $retry.revision -ne $set.revision) { throw 'not saved, or the retry was applied twice' }
        $stale = try { Api PUT '/api/v1/exercise-increments/bench-press' @{ operationId = [Guid]::NewGuid(); expectedRevision = 0; incrementKg = 5 } $token } catch { if ((Status $_) -ne 409) { throw }; 'conflict' }
        if ($stale -ne 'conflict') { throw 'a stale revision was accepted' }
        Api PUT '/api/v1/exercise-increments/bench-press' @{ operationId = [Guid]::NewGuid(); expectedRevision = $set.revision; incrementKg = $null } $token | Out-Null
        if ($null -ne (@((Api GET '/api/v1/sync/snapshot' $null $token).exerciseIncrements) | Where-Object exerciseKey -eq 'bench-press').incrementKg) { throw 'not cleared' }
        'saved, retried once, stale refused, cleared'
    }
} else { Write-Host '  SKIP  Weight increments - this server does not declare exercises.load-increment (deploy needed)' -ForegroundColor Yellow }
if ($capabilities -contains 'runs.routes') {
    Check 'Run / Walk: a walk, its route in a chunk retried once, completed, read back and erased with the walk' {
        $id = [Guid]::NewGuid(); $at = [DateTime]::UtcNow.AddMinutes(-20).ToString('o')
        Api POST '/api/v1/runs' @{ operationId = [Guid]::NewGuid(); runId = $id; dayKey = $today; startedAtUtc = $at; activityType = 'walk' } $token | Out-Null
        $done = Api POST "/api/v1/runs/$id/finish" @{ operationId = [Guid]::NewGuid(); expectedRevision = 1; activeDurationSeconds = 600; distanceMeters = 800; finishedAtUtc = [DateTime]::UtcNow.ToString('o'); title = 'Verification walk'; metrics = @{ distanceSource = 'gps' } } $token
        # Synthetic entries (not a real place): a start and three fixes.
        $entries = @(@{ s = 0; y = 'start'; g = 0; t = 1 }) + @(1..3 | ForEach-Object { @{ s = $_; y = 'fix'; g = 0; t = 1 + $_ * 1000; la = 0.001 * $_; lo = 0.0; a = 5 } })
        $chunk = @{ operationId = [Guid]::NewGuid(); firstSeq = 0; lastSeq = 3; entries = $entries }
        $a = Api PUT "/api/v1/runs/$id/route/chunks/0" $chunk $token
        $b = Api PUT "/api/v1/runs/$id/route/chunks/0" $chunk $token
        $c = Api POST "/api/v1/runs/$id/route/complete" @{ operationId = [Guid]::NewGuid(); chunkCount = 1; entryCount = 4 } $token
        $page = Api GET "/api/v1/runs/$id/route" $null $token
        if ($done.data.activityType -ne 'walk' -or $a.status -ne 'accepted' -or $b.status -ne 'accepted' -or $c.data.routeState -ne 'complete' -or @($page.chunks[0].entries).Count -ne 4) { throw 'walk or route not stored as sent' }
        if ((Api GET '/api/v1/sync/snapshot' $null $token | ConvertTo-Json -Depth 8) -match '"la"') { throw 'route points appeared in the snapshot' }
        Api POST "/api/v1/runs/$id/delete" @{ operationId = [Guid]::NewGuid(); expectedRevision = $done.revision } $token | Out-Null
        try { Api GET "/api/v1/runs/$id/route" $null $token | Out-Null; throw 'route still readable after delete' } catch { if ((Status $_) -ne 404) { throw } }
        'walk kept as walk; chunk idempotent; route complete, paged, not in the snapshot, erased on delete'
    }
} else { Write-Host '  SKIP  Run / Walk routes - this server does not declare runs.routes' -ForegroundColor Yellow }
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
function Uuid5([Guid]$ns, [string]$name) {   # RFC 4122 v5, namespace bytes in network order (docs/TRAINING_PLANS.md)
    $n = $ns.ToByteArray(); [Array]::Reverse($n, 0, 4); [Array]::Reverse($n, 4, 2); [Array]::Reverse($n, 6, 2)
    $b = [byte[]]([Security.Cryptography.SHA1]::Create().ComputeHash([byte[]]($n + [Text.Encoding]::UTF8.GetBytes($name)))[0..15])
    $b[6] = [byte](($b[6] -band 0x0F) -bor 0x50); $b[8] = [byte](($b[8] -band 0x3F) -bor 0x80)
    [Array]::Reverse($b, 0, 4); [Array]::Reverse($b, 4, 2); [Array]::Reverse($b, 6, 2)
    New-Object Guid (,$b)
}
if ($capabilities -contains 'plans.builder') {
    Check 'Plan builder: custom exercise, rotating plan, step 0 started from the plan, finished and credited, then revised' {
        $customId = [Guid]::NewGuid()
        $c = Api PUT "/api/v1/custom-exercises/$customId" @{ operationId = [Guid]::NewGuid(); expectedRevision = 0; name = 'Verification sled push'; category = 'Legs'; equipment = 'Machine'; isTimed = $false; isArchived = $false } $token
        if ($c.status -ne 'accepted') { throw "custom exercise: $($c.code)" }
        $planId = [Guid]::NewGuid(); $wa = "$([Guid]::NewGuid())"; $wb = "$([Guid]::NewGuid())"
        $ex = { param($catalogKey, $name) @{ occurrenceKey = 'e1'; catalogKey = $catalogKey; name = $name; isTimed = $false; targetSets = 1; targetRepsMin = 5; targetRepsMax = 10; targetDurationSeconds = $null; restSeconds = 90 } }
        $workouts = @(
            @{ id = $wa; name = 'Verify A'; notes = $null; exercises = @((& $ex 'bench-press' 'Bench press')) },
            @{ id = $wb; name = 'Verify B'; notes = $null; exercises = @((& $ex "custom:$customId" 'Verification sled push')) })
        $schedule = @{ mode = 'rotating'; pattern = @(); cycle = @($wa, $wb); trainingDays = @(); cycleAnchor = 0 }
        $created = Api POST '/api/v1/plans' @{ operationId = [Guid]::NewGuid(); planId = "$planId"; title = 'Verification rotation'; startDate = $today; durationWeeks = $null; timeBudgetMinutes = $null; templateId = $null; workouts = $workouts; schedule = $schedule } $token
        if ($created.status -ne 'accepted') { throw "plan.create: $($created.code)" }
        $draft = @($created.data.plans | Where-Object { $_.id -eq "$planId" })[0]
        if ($draft.lifecycle -ne 'draft' -or $null -ne $created.data.primaryPlanId) { throw 'plan.create did more than create a draft' }
        $act = Api POST "/api/v1/plans/$planId/activate" @{ operationId = [Guid]::NewGuid(); expectedContextRevision = $created.data.contextRevision; expectedPlanRevision = $draft.revision; startDate = $today; reviewedDates = @(); replacePrimaryId = $null; closePrimary = $false; effectiveDate = $today } $token
        if ($act.status -ne 'accepted') { throw "activate: $($act.code)" }
        $active = @($act.data.plans | Where-Object { $_.id -eq "$planId" })[0]

        $stepId = Uuid5 $planId 's:0'; $exerciseId = [Guid]::NewGuid()
        $start = Api POST '/api/v1/workouts' @{ operationId = [Guid]::NewGuid(); workoutId = [Guid]::NewGuid(); kind = 'planned'; occasionId = "$stepId"; title = 'Verify A'; dayKey = $today; startedAtUtc = [DateTime]::UtcNow.ToString('o'); planId = "$planId"; sequenceIndex = 0
            exercises = @(@{ id = "$exerciseId"; ordinal = 1; name = 'Bench press'; catalogKey = 'bench-press'; occurrenceKey = 'e1'; isPrescribed = $true; isTimed = $false; targetSets = 1; targetRepsMin = 5; targetRepsMax = 10; targetDurationSeconds = $null; restSeconds = 90; substitutedForKey = $null }) } $token
        if ($start.status -ne 'accepted') { throw "start of step 0: $($start.code)" }
        $set = Api POST "/api/v1/exercises/$exerciseId/sets" @{ operationId = [Guid]::NewGuid(); setId = [Guid]::NewGuid(); reps = 5; loadKg = 40; durationSeconds = $null; performedAtUtc = [DateTime]::UtcNow.ToString('o') } $token
        $finish = Api POST "/api/v1/workouts/$($start.data.id)/finish" @{ operationId = [Guid]::NewGuid(); expectedRevision = $start.data.revision; acknowledgedSets = @(@{ id = $set.data.id; revision = $set.data.revision }); activeDurationSeconds = 60; finishedAtUtc = [DateTime]::UtcNow.ToString('o') } $token
        if ($finish.status -ne 'accepted' -or -not $finish.data.qualifiedOccasion) { throw 'the finish did not credit step 0' }

        $s = Api GET '/api/v1/sync/snapshot' $null $token
        $p = @($s.context.plans | Where-Object { $_.id -eq "$planId" })[0]
        $steps = @($p.occasions)
        if ($steps.Count -ne 1 -or $steps[0].id -ne "$stepId" -or $steps[0].sequenceIndex -ne 0 -or $steps[0].resultOutcome -ne 'full') { throw 'step 0 is not the one credited occurrence' }
        if ($p.revision -ne $active.revision -or $p.title -ne $active.title -or @($p.workouts).Count -ne 2 -or $p.schedule.mode -ne 'rotating') { throw 'the plan itself changed' }
        if (@($s.customExercises | Where-Object { $_.id -eq "$customId" }).Count -ne 1) { throw 'the custom exercise is missing from the snapshot' }

        $workouts[1].name = 'Verify B (revised)'
        $rev = Api PUT "/api/v1/plans/$planId" @{ operationId = [Guid]::NewGuid(); expectedPlanRevision = $p.revision; effectiveDate = $today; title = 'Verification rotation'; startDate = $today; durationWeeks = $null; timeBudgetMinutes = 30; workouts = $workouts; schedule = $schedule } $token
        $after = @($rev.data.plans | Where-Object { $_.id -eq "$planId" })[0]
        if ($rev.status -ne 'accepted' -or $after.revision -ne $p.revision + 1 -or @($after.occasions).Count -ne 1 -or $after.occasions[0].resultOutcome -ne 'full') { throw "revise: $($rev.code)" }
        "step 0 credited, plan unchanged by it, revised to revision $($after.revision)"
    }
} else { Write-Host '  SKIP  Plan builder - this server does not declare plans.builder' -ForegroundColor Yellow }
# Ask GoHard (docs/COACH.md). A small Upper/Lower draft with real catalog keys; every answer is checked against the
# contract, and any proposal may only name workouts and occurrence keys that were sent (the server drops the rest).
$wu = "$([Guid]::NewGuid())"; $wl = "$([Guid]::NewGuid())"
$cx = { param($key, $catalogKey, $name) @{ occurrenceKey = $key; catalogKey = $catalogKey; name = $name; isTimed = $false; targetSets = 3; targetRepsMin = 8; targetRepsMax = 12; targetDurationSeconds = $null; restSeconds = 90 } }
$coachDraft = @{ title = 'Verify Upper / Lower'; durationWeeks = 8; timeBudgetMinutes = 45
    schedule = @{ mode = 'rotating'; pattern = @(); cycle = @($wu, $wl); trainingDays = @(); cycleAnchor = 0 }
    workouts = @(
        @{ id = $wu; name = 'Upper A'; notes = $null; exercises = @((& $cx 'e1' 'bench-press' 'Bench press'), (& $cx 'e2' 'barbell-row' 'Barbell row')) },
        @{ id = $wl; name = 'Lower A'; notes = $null; exercises = @((& $cx 'e1' 'back-squat' 'Back squat'), (& $cx 'e2' 'romanian-deadlift' 'Romanian deadlift')) }) }
$splitContext = @{ label = 'Upper / Lower'; focus = 'split'; templateId = 'upper-lower'; workoutId = $null; occurrenceKey = $null; catalogKey = $null; draft = $coachDraft; draftRevision = 'verify-1' }
function CoachAsk($question, $context, $history) {
    try { @{ ok = $true; data = (Api POST '/api/v1/coach/ask' @{ requestId = [Guid]::NewGuid(); question = $question; history = @($history); context = $context } $token) } }
    catch {
        $err = $_; $text = $err.ErrorDetails.Message
        if (-not $text) { try { $st = $err.Exception.Response.GetResponseStream(); $st.Position = 0; $text = (New-Object IO.StreamReader $st).ReadToEnd() } catch { } }   # PS 5.1 leaves ErrorDetails empty for chunked bodies
        $e = $null; if ($text) { try { $e = $text | ConvertFrom-Json } catch { } }
        @{ ok = $false; status = (Status $err); code = $e.code; retry = $e.retryAfterSeconds }
    }
}
$coachHalt = $null
function Ask($name, $question, $context, $history, [scriptblock]$more) {   # one live call; returns the answer or $null
    if ($script:coachHalt) { Write-Host "  SKIP  [LIVE] $name - $script:coachHalt" -ForegroundColor Yellow; return }
    $r = CoachAsk $question $context $history
    if (-not $r.ok -and $r.code -in 'COACH_BUSY', 'COACH_LIMIT') {
        $script:coachHalt = "not asked after $($r.code)"
        Write-Host "  BUSY  [LIVE] $name - HTTP $($r.status) $($r.code)$(if ($r.retry) { ", retry after $($r.retry) s" }): the provider or our limit refused; not a contract failure, remaining coach checks skipped" -ForegroundColor Yellow
        return
    }
    Check "[LIVE] $name" {
        if (-not $r.ok) { throw "HTTP $($r.status) $($r.code)" }
        $d = $r.data
        if ($d.kind -ne 'ai' -or -not "$($d.answer)".Trim() -or $d.answer.Length -gt 1200) { throw "unexpected answer (kind=$($d.kind), $("$($d.answer)".Length) chars)" }
        $unknown = @($d.sources | Where-Object { $_ -notin $guideSources })
        if ($unknown) { throw "sources outside the guide: $($unknown -join ', ')" }
        $p = if ($d.proposal) {
            foreach ($op in @($d.proposal.operations)) {
                $w = @($coachDraft.workouts | Where-Object { $_.id -eq $op.workoutId })
                if (-not $w) { throw "proposal names workout $($op.workoutId), which was not sent" }
                if ($op.occurrenceKey -and -not @($w[0].exercises | Where-Object { $_.occurrenceKey -eq $op.occurrenceKey })) { throw "proposal names $($op.occurrenceKey) in $($w[0].name), which was not sent" }
            }
            "proposal '$($d.proposal.summary)' ($(@($d.proposal.operations).Count) op(s), all on sent IDs)"
        } else { 'no proposal' }
        $extra = if ($more) { & $more $d }
        "$($d.answer.Length) chars, sources [$(@($d.sources) -join ', ')], $p$(if ($extra) { "; $extra" })"
    } | Out-Null   # only the data is returned: a caller reads .answer from it
    if ($r.ok) { $r.data }
}
if ($capabilities -contains 'coach.ask') {
    # Live model calls, counted against this throwaway account's daily cap (40): 1 by default, 5 with -Coach.
    $guideSources = @((Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot '..\api\src\GoHard.Api\Data\coach-guide.json') | ConvertFrom-Json).sources | ForEach-Object { $_.id })
    Write-Host '  Ask GoHard: LIVE provider results (model output varies between runs)' -ForegroundColor Cyan
    $q1 = 'Is this Upper/Lower split a good fit for 3 days a week, and what does it trade off?'
    $a1 = Ask 'Contextual split question with an Upper/Lower draft' $q1 $splitContext @()
    if ($Coach) {
        if ($a1) { Ask 'Follow-up using history' 'Which of the two workouts should I do first this week, and why?' $splitContext @(@{ role = 'user'; text = $q1 }, @{ role = 'assistant'; text = [string]$a1.answer }) | Out-Null }
        else { Write-Host '  SKIP  [LIVE] Follow-up using history - the first question gave no answer' -ForegroundColor Yellow }
        Ask 'Exercise explanation (focus=exercise, bench-press in Upper A)' 'How do I do this exercise well, and what does it train?' `
            @{ label = 'Bench press'; focus = 'exercise'; templateId = 'upper-lower'; workoutId = $wu; occurrenceKey = 'e1'; catalogKey = 'bench-press'; draft = $coachDraft; draftRevision = 'verify-1' } @() | Out-Null
        Ask 'Proposal-inviting question (replace bench press with a dumbbell exercise)' 'Can I replace bench press with a dumbbell exercise in Upper A?' $splitContext @() {
            param($d) if (-not $d.proposal) { 'INFO: no proposal offered (the model may decline)' } } | Out-Null
        Ask 'Change a workout that is not in the draft (server keeps proposals to sent IDs)' "Replace the squat in my 'Leg Day C' workout (id $([Guid]::NewGuid())) with leg press." $splitContext @() | Out-Null
    } else { Write-Host '  INFO  [LIVE] 4 more coach checks (history, exercise, proposal, invalid ID) run with -Coach' -ForegroundColor Cyan }
} else {
    Write-Host '  NOT CONFIGURED  coach: not configured (capability absent) - set the provider key to enable Ask GoHard' -ForegroundColor Yellow
    if ($Coach) {
        Check 'Coach request shape is accepted (no model call: 503 COACH_UNAVAILABLE, not 400 COACH_INVALID)' {
            $r = CoachAsk 'Is this Upper/Lower split a good fit?' $splitContext @()
            if ($r.ok -or $r.status -ne 503 -or $r.code -ne 'COACH_UNAVAILABLE') { throw "expected 503 COACH_UNAVAILABLE, got $(if ($r.ok) { '200' } else { "$($r.status) $($r.code)" })" }
            '503 COACH_UNAVAILABLE'
        }
    }
}
} catch {
    $failed = $true; Write-Host "  ABORTED  $(Redact $_.Exception.Message)" -ForegroundColor Red
} finally {
    # Runs after success, a failing check, an exception or Ctrl+C. Reported apart from the feature checks.
    $cleanup = 'deleted'
    if (-not $registerAttempted) { $cleanup = 'nothing to clean (no registration attempted)' }
    else {
        try {
            $t = $token
            try { Api DELETE '/api/v1/account' @{ password = $password } $t | Out-Null }
            catch {
                if ((Status $_) -ne 401) { throw }
                # No token (registration answer lost) or an expired one: sign in again with the stored credentials.
                try { $t = (Api POST '/api/v1/auth/login' @{ email = $email; password = $password }).accessToken }
                catch {
                    if ((Status $_) -ne 401) { throw }
                    if ($accountId) { throw 'cannot sign in to delete it (401)' }
                    $t = $null; $cleanup = 'nothing to clean (registration did not create an account)'
                }
                if ($t) { Api DELETE '/api/v1/account' @{ password = $password } $t | Out-Null }
            }
            if ($t) {
                try { Api GET '/api/v1/me' $null $t | Out-Null; throw 'its token still works after deletion' } catch { if ((Status $_) -ne 401) { throw } }
                try { Api POST '/api/v1/auth/login' @{ email = $email; password = $password } | Out-Null; throw 'it can still sign in after deletion' } catch { if ((Status $_) -ne 401) { throw } }
            }
        } catch { $cleanup = "FAILED ($(Redact $_.Exception.Message))" }
        Record "cleanup: $cleanup"
    }
    if ($cleanup -like 'FAILED*') {
        Write-Host "Cleanup: $cleanup - $email was LEFT on $BaseUrl. Delete it with:" -ForegroundColor Red
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\delete-verify-account.ps1 -BaseUrl $BaseUrl -Email $email" -ForegroundColor Red
    } else { Write-Host "Cleanup: $cleanup$(if ($cleanup -eq 'deleted') { " - $email (/me and sign-in now 401)" })" -ForegroundColor Green }
}
if ($cleanup -like 'FAILED*') { Write-Host "API verification: checks $(if ($failed) { 'FAILED' } else { 'passed' }), cleanup FAILED." -ForegroundColor Red; exit 2 }
if ($failed) { Write-Host 'API verification FAILED (account cleaned up).' -ForegroundColor Red; exit 1 }
Write-Host 'API verification passed.' -ForegroundColor Green
