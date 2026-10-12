<#
.SYNOPSIS
  Serves the recorded Open Food Facts and USDA responses from the API test fixtures on http://localhost:5132, so
  the local API can be exercised end to end (and by the native journeys) without calling either provider.
  Started for you by:  scripts\start-api.ps1 -FoodFixtures

  This is a stand-in for the providers. Passing a journey against it proves the app and the API's adapters work
  together; it does NOT prove the live providers answer. For that, run scripts\verify-api.ps1 against an API that
  has a real USDA key.
#>
param([int]$Port = 5132)
$fixtures = Join-Path (Split-Path -Parent $PSScriptRoot) 'api\tests\GoHard.Api.Tests\Fixtures'
$products = @{ '3017620422003' = 'off_product_100g.json'; '5449000000996' = 'off_product_100ml.json' }
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Recorded food provider responses on http://localhost:$Port (Ctrl+C to stop)"
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $path = $context.Request.Url.AbsolutePath
        $status = 200
        if ($path -match '^/off/api/v3\.6/product/(\d+)\.json$') {
            $file = $products[$Matches[1]]
            if (-not $file) { $file = 'off_not_found.json'; $status = 404 }
        } elseif ($path -eq '/usda/foods/search') {
            $file = if ($context.Request.QueryString['dataType'] -match 'Branded') { 'usda_search_branded.json' } else { 'usda_search_generic.json' }
        } else { $file = $null; $status = 404 }
        $bytes = if ($file) { [System.IO.File]::ReadAllBytes((Join-Path $fixtures $file)) } else { [Text.Encoding]::UTF8.GetBytes('{}') }
        $context.Response.StatusCode = $status
        $context.Response.ContentType = 'application/json'
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.Close()
    }
} finally { $listener.Stop() }
