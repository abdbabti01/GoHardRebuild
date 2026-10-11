<#
.SYNOPSIS
  Starts the GoHard rebuild API. It only reads schema readiness; run setup.ps1 to migrate.
.PARAMETER Lan
  Listen on all interfaces so a physical phone on the same network can reach the API.
#>
param([switch]$Lan)
. "$PSScriptRoot\common.ps1"
Assert-DotNet10
if (-not (Test-Path $LocalConfig)) { Fail 'Local configuration is missing. Run .\scripts\setup.ps1 first.' }
if (Test-PortInUse $ApiPort) { Fail "Port $ApiPort is already in use. Is the API already running?" }
$bind = if ($Lan) { "http://0.0.0.0:$ApiPort" } else { "http://127.0.0.1:$ApiPort" }
Step "Starting API on $bind (readiness: $bind/health/ready)"
$env:ASPNETCORE_ENVIRONMENT = 'Development'
dotnet run --project $ApiProject -- --urls $bind
