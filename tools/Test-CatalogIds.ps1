<#
  Maintainer check: does every id in catalog.json still exist in winget / Scoop?
  Package ids get renamed over time, so run this before a release.
  Needs winget and Scoop installed. Installs nothing.
#>
param([string]$CatalogPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'catalog.json'))

Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'src/DevSetup.psm1') -Force
$catalog = Get-DevCatalog -Path $CatalogPath
$missing = @()

foreach ($app in $catalog.apps) {
    switch ($app.manager) {
        'scoop'   { $found = (scoop info $app.id 2>&1 | Out-String) -match 'Name\s*:' }
        'msstore' { $found = (winget show --id $app.id --source msstore --accept-source-agreements 2>&1 | Out-String) -match 'Found ' }
        default   { $found = (winget show --id $app.id --exact --source winget --accept-source-agreements 2>&1 | Out-String) -match 'Found ' }
    }
    if ($found) { Write-Host "  ok    $($app.id)" -ForegroundColor DarkGray }
    else        { Write-Host "  MISS  $($app.id)" -ForegroundColor Red; $missing += $app.id }
}

if ($missing) { Write-Host "`n$($missing.Count) id(s) not found: $($missing -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "`nAll $(@($catalog.apps).Count) ids exist." -ForegroundColor Green
