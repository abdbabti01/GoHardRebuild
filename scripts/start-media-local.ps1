# Local owner-video stack (docs/OWNER_EXERCISE_VIDEOS.md › Local verification): an S3-compatible store (SeaweedFS, standing
# in for Cloudflare R2) with a private staging bucket and a public read-only bucket, and the API's real Linux image (with
# FFmpeg) on port 5131, so the emulator can upload, process, preview and publish exactly as a phone would against R2.
#
#   scripts\start-media-local.ps1 [-OwnerUserId <guid from GET /api/v1/me> | -LocalOwner] [-Build]
#
# Without an owner nobody can manage (the safe default). -LocalOwner uses (or, the first time, registers through the API)
# a local test owner account kept in build\media-local\owner.json, as a real owner would be configured from GET /me. Local credentials are generated once into build\media-local
# (git-ignored). Uses only this project's resources: containers gohard-rebuild-s3 and gohard-rebuild-api-media, volume
# gohard_rebuild_s3, the existing gohard_rebuild_dev database, ports 8333 and 5131.
param([string]$OwnerUserId = '', [switch]$LocalOwner, [switch]$Build)
. "$PSScriptRoot\common.ps1"
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$local = Join-Path $Root 'build\media-local'
New-Item -ItemType Directory -Force $local | Out-Null
$ownerFile = Join-Path $local 'owner.json'
if ($LocalOwner -and (Test-Path $ownerFile)) { $OwnerUserId = ([IO.File]::ReadAllText($ownerFile) | ConvertFrom-Json).userId }

# Local-only credentials, generated once.
$credsFile = Join-Path $local 'credentials.json'
if (-not (Test-Path $credsFile)) {
    $rand = { -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) }) }
    [IO.File]::WriteAllText($credsFile, (@{ accessKey = "gohard$(& $rand)".Substring(0, 20); secretKey = & $rand } | ConvertTo-Json))
}
$creds = [IO.File]::ReadAllText($credsFile) | ConvertFrom-Json
$s3Config = @{ identities = @(
    @{ name = 'gohard'; credentials = @(@{ accessKey = $creds.accessKey; secretKey = $creds.secretKey }); actions = @('Admin', 'Read', 'Write', 'List', 'Tagging') },
    # Anyone may read the PUBLIC bucket only, as an R2 public bucket on a custom domain allows. Staging stays private.
    @{ name = 'anonymous'; actions = @('Read:gohard-public') }
) } | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $local 's3.json'), $s3Config)

if (-not (docker ps -q -f name=^gohard-rebuild-s3$)) {
    docker rm -f gohard-rebuild-s3 2>$null | Out-Null
    docker run -d --name gohard-rebuild-s3 -p 8333:8333 -v gohard_rebuild_s3:/data -v "${local}:/etc/gohard" `
        chrislusf/seaweedfs:3.97 server '-dir=/data' -s3 '-s3.port=8333' '-s3.config=/etc/gohard/s3.json' | Out-Null   # quoted: PowerShell splits -a.b=c at the dot
    Start-Sleep -Seconds 8
}
$ErrorActionPreference = 'Continue'   # weed shell writes progress to stderr
for ($i = 0; $i -lt 30; $i++) {
    foreach ($bucket in 'gohard-staging', 'gohard-public') {
        "s3.bucket.create -name $bucket" | docker exec -i gohard-rebuild-s3 weed shell -master=localhost:9333 2>&1 | Out-Null
    }
    $list = ("s3.bucket.list" | docker exec -i gohard-rebuild-s3 weed shell -master=localhost:9333 2>&1) -join ' '
    if ($list -match 'gohard-staging' -and $list -match 'gohard-public') { break }
    Start-Sleep -Seconds 2
}
if ($list -notmatch 'gohard-public') { throw 'The local S3 store did not come up.' }
$ErrorActionPreference = 'Stop'
Write-Host 'S3 store: http://localhost:8333 (buckets gohard-staging, gohard-public)'

if ($Build -or -not (docker images -q gohard-rebuild-api:media)) {
    docker build -t gohard-rebuild-api:media (Join-Path $Root 'api')
    if ($LASTEXITCODE -ne 0) { throw 'The API image did not build.' }
}

$settings = [IO.File]::ReadAllText((Join-Path $Root 'api\src\GoHard.Api\appsettings.Local.json')) | ConvertFrom-Json
$cs = @{}
foreach ($part in $settings.ConnectionStrings.Default.Split(';')) { if ($part -match '^(\w+)=(.*)$') { $cs[$Matches[1]] = $Matches[2] } }
$dbUrl = "postgres://$($cs.Username):$([uri]::EscapeDataString($cs.Password))@host.docker.internal:$($cs.Port)/$($cs.Database)"
$envs = @(
    '-e', "DATABASE_URL=$dbUrl", '-e', 'PORT=8080', '-e', 'ASPNETCORE_ENVIRONMENT=Development',
    '-e', "GOHARD_Auth__SigningKey=$($settings.Auth.SigningKey)",
    '-e', "GOHARD_ExerciseMedia__OwnerUserId=$OwnerUserId",
    '-e', 'GOHARD_ExerciseMedia__ServiceUrl=http://host.docker.internal:8333',
    # The emulator reaches the store at 10.0.2.2: links the phone receives are signed for that host.
    '-e', 'GOHARD_ExerciseMedia__PresignServiceUrl=http://10.0.2.2:8333',
    '-e', 'GOHARD_ExerciseMedia__PublicBaseUrl=http://10.0.2.2:8333/gohard-public',
    '-e', "GOHARD_ExerciseMedia__AccessKeyId=$($creds.accessKey)", '-e', "GOHARD_ExerciseMedia__SecretAccessKey=$($creds.secretKey)",
    '-e', 'GOHARD_ExerciseMedia__StagingBucket=gohard-staging', '-e', 'GOHARD_ExerciseMedia__PublicBucket=gohard-public'
)
docker run --rm @envs gohard-rebuild-api:media migrate seed-catalog
if ($LASTEXITCODE -ne 0) { throw 'Migration failed.' }
docker rm -f gohard-rebuild-api-media 2>$null | Out-Null
docker run -d --name gohard-rebuild-api-media -p 5131:8080 @envs gohard-rebuild-api:media | Out-Null
for ($i = 0; $i -lt 30; $i++) {
    try { if ((Invoke-WebRequest -UseBasicParsing http://localhost:5131/health/ready -TimeoutSec 2).StatusCode -eq 200) { break } } catch { Start-Sleep -Seconds 1 }
}
if ($LocalOwner -and -not $OwnerUserId) {
    # The first time: register the local owner through the API and use the ID its own /me reports, then restart with it.
    $email = "owner-local-$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())@example.test"
    $password = 'owner local ' + (-join ((1..12) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) }))
    $auth = Invoke-RestMethod -Method Post http://localhost:5131/api/v1/auth/register -ContentType 'application/json' -Body (@{ email = $email; password = $password; displayName = 'Local Owner' } | ConvertTo-Json)
    $me = Invoke-RestMethod http://localhost:5131/api/v1/me -Headers @{ Authorization = "Bearer $($auth.accessToken)" }
    [IO.File]::WriteAllText($ownerFile, (@{ email = $email; password = $password; userId = $me.userId } | ConvertTo-Json))
    & $PSCommandPath -LocalOwner
    return
}
Write-Host "API (Linux image, worker on): http://localhost:5131  owner: $(if ($OwnerUserId) { 'configured' } else { 'none (management off)' })"
