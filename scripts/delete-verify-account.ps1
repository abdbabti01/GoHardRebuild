<#
.SYNOPSIS
  Deletes ONE account left behind by scripts\verify-api.ps1: signs in with the verification password, deletes it
  through DELETE /api/v1/account, then checks /me and sign-in answer 401. Takes an exact email only (no patterns);
  the email must look like verify-<hex>@example.test. Prints no password or token.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\delete-verify-account.ps1 -BaseUrl https://<api> -Email verify-0123abcd@example.test
#>
param([Parameter(Mandatory)][string]$BaseUrl, [Parameter(Mandatory)][string]$Email)
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$Email = $Email.Trim().ToLowerInvariant()
$password = 'verify password 1'   # the fixed verification password (see verify-api.ps1)
if ($Email -notmatch '^verify-[0-9a-f]{8,32}@example\.test$') {
    Write-Host "Refused: '$Email' is not one exact verification email (verify-<hex>@example.test). Patterns and wildcards are not accepted." -ForegroundColor Red; exit 1
}
function Api($method, $path, $body, $token) {
    $headers = @{}; if ($token) { $headers.Authorization = "Bearer $token" }
    Invoke-RestMethod -Method $method -Uri "$BaseUrl$path" -Headers $headers -TimeoutSec 30 -ContentType 'application/json' -Body ($body | ConvertTo-Json)
}
function Status($err) { try { [int]$err.Exception.Response.StatusCode } catch { 0 } }
$log = Join-Path $PSScriptRoot '.verify-accounts.log'
function Record($id, $outcome) { Add-Content -Path $log -Encoding UTF8 -Value "$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))  $BaseUrl  $Email  id=$id  delete-verify-account: $outcome" }

try { $auth = Api POST '/api/v1/auth/login' @{ email = $Email; password = $password } }
catch {
    if ((Status $_) -eq 401) { Write-Host "Nothing deleted: $Email cannot sign in with the verification password (already gone, or not a verification account)." -ForegroundColor Yellow; exit 1 }
    Write-Host "Sign-in failed: $($_.Exception.Message)" -ForegroundColor Red; exit 1
}
$id = $auth.profile.userId
Write-Host "Deleting $Email (id $id, display name '$($auth.profile.displayName)') on $BaseUrl"
try {
    Api DELETE '/api/v1/account' @{ password = $password } $auth.accessToken | Out-Null
    try { Api GET '/api/v1/me' $null $auth.accessToken | Out-Null; throw 'its token still works' } catch { if ((Status $_) -ne 401) { throw } }
    try { Api POST '/api/v1/auth/login' @{ email = $Email; password = $password } | Out-Null; throw 'it can still sign in' } catch { if ((Status $_) -ne 401) { throw } }
} catch {
    Record $id "FAILED"
    Write-Host "FAILED: $(($_.Exception.Message) -replace 'Bearer\s+\S+', 'Bearer <redacted>')" -ForegroundColor Red; exit 2
}
Record $id 'deleted'
Write-Host "Deleted: $Email (/me and sign-in now 401)" -ForegroundColor Green
