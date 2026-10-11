# Shared settings for the GoHard rebuild scripts. Dot-source it: . "$PSScriptRoot\common.ps1"
$ErrorActionPreference = 'Stop'
$Root        = Split-Path -Parent $PSScriptRoot
$ApiProject  = Join-Path $Root 'api\src\GoHard.Api'
$AppDir      = Join-Path $Root 'app'
$ComposeFile = Join-Path $Root 'infrastructure\docker-compose.yml'
$EnvFile     = Join-Path $Root 'infrastructure\.env.local'
$LocalConfig = Join-Path $ApiProject 'appsettings.Local.json'
$DbContainer = 'gohard-rebuild-postgres'
$DbName      = 'gohard_rebuild_dev'
$DbUser      = 'gohard_rebuild'
$DbPort      = 5435
$ApiPort     = 5131

function Fail($message) { Write-Host "ERROR: $message" -ForegroundColor Red; exit 1 }
function Step($message) { Write-Host "==> $message" -ForegroundColor Cyan }

function Test-PortInUse([int]$port) {
    [bool](Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
}

function Assert-Tool($name, $hint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) { Fail "$name was not found. $hint" }
}

function Assert-Docker {
    Assert-Tool docker 'Install Docker Desktop and start it.'
    docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail 'Docker is installed but the engine is not running. Start Docker Desktop and retry.' }
}

function Assert-DotNet10 {
    Assert-Tool dotnet 'Install the .NET 10 SDK from https://dotnet.microsoft.com/download/dotnet/10.0 (side by side with existing SDKs).'
    if (-not (dotnet --list-sdks | Select-String '^10\.')) {
        Fail 'No .NET 10 SDK is installed. Install it side by side from https://dotnet.microsoft.com/download/dotnet/10.0; do not remove older SDKs.'
    }
}

function New-Secret([int]$bytes = 36) {
    $buffer = New-Object byte[] $bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
    ([Convert]::ToBase64String($buffer)) -replace '[+/=]', 'x'
}
