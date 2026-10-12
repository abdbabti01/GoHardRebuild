<#
.SYNOPSIS
  Verifies a running GoHard rebuild API end to end: readiness, client/backend contract compatibility,
  registration, sign-in, an idempotent write, reading it back, and account deletion (so no test data is left).
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
Check 'Exercise catalog is seeded' { $s = Api GET '/api/v1/sync/snapshot' $null $token; if ($s.catalog.Count -lt 1) { throw 'catalog is empty: run seed-catalog' }; "$($s.catalog.Count) movements" }
Check 'Cleanup: the verification account is deleted' {
    Api DELETE '/api/v1/account' @{ password = $password } $token | Out-Null
    try { Api GET '/api/v1/me' $null $token | Out-Null; throw 'token still works after deletion' } catch { if ($_.Exception.Response.StatusCode.value__ -ne 401) { throw }; 'no test data left behind' }
}
if ($failed) { Write-Host 'API verification FAILED.' -ForegroundColor Red; exit 1 }
Write-Host 'API verification passed.' -ForegroundColor Green
