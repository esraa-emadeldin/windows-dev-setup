<#
.SYNOPSIS
  Install a curated set of developer apps on Windows - plan first, then apply.

.EXAMPLE
  .\setup.ps1 -List                                   # show every category and app
  .\setup.ps1 -Category core,terminal,web -Plan       # show what WOULD happen (changes nothing)
  .\setup.ps1 -Category core,terminal,web             # install
  .\setup.ps1 -Category all -InstallRoot D:\Dev\Tools -CacheRoot D:\Dev\.cache
#>
[CmdletBinding()]
param(
    # Which groups of apps to install (see -List). 'all' = everything.
    [string[]]$Category = @('core'),
    # Only show the plan; install nothing.
    [switch]$Plan,
    # Print the catalog and exit.
    [switch]$List,
    # Optional: install apps that support it (and Scoop) under this folder, e.g. D:\Dev\Tools
    [string]$InstallRoot,
    # Optional: move npm/pip/uv/NuGet/Gradle caches under this folder, e.g. D:\Dev\.cache
    [string]$CacheRoot,
    # Use a different catalog file (handy for your own fork)
    [string]$CatalogPath = (Join-Path $PSScriptRoot 'catalog.json')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'src\DevSetup.psm1') -Force

$catalog  = Get-DevCatalog -Path $CatalogPath
$problems = Test-DevCatalog -Catalog $catalog
if ($problems.Count) { throw "catalog.json has problems:`n  $($problems -join "`n  ")" }

# --- -List: print the catalog ------------------------------------------------
if ($List) {
    foreach ($cat in $catalog.categories.PSObject.Properties) {
        Write-Host "`n$($cat.Name)" -ForegroundColor Cyan -NoNewline
        Write-Host "  - $($cat.Value)" -ForegroundColor DarkGray
        foreach ($a in $catalog.apps | Where-Object category -eq $cat.Name) {
            # Same stream as the headings above, so lines can't come out of order
            Write-Host ('  {0,-22} {1}' -f $a.name, $a.why)
        }
    }
    return
}

# --- Check the package managers we need -------------------------------------
$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$hasScoop  = [bool](Get-Command scoop -ErrorAction SilentlyContinue)
if (-not $hasWinget) { throw 'winget is missing. Install "App Installer" from the Microsoft Store, then run this again.' }

# Real "is it installed?" check, handed to the plan as a scriptblock
$isInstalled = {
    param($app)
    # Already on PATH (installed any way, even by hand)? Then don't install a second copy.
    if ($app.command -and (Get-Command $app.command -ErrorAction SilentlyContinue)) { return $true }
    if ($app.manager -eq 'scoop') {
        if (-not $hasScoop) { return $false }
        scoop prefix ($app.id -split '/')[-1] *> $null   # succeeds only if installed
    } else {
        winget list --id $app.id --exact --accept-source-agreements *> $null
    }
    return ($LASTEXITCODE -eq 0)
}

$apps = Select-DevApp -Catalog $catalog -Category $Category
Write-Host "Checking $($apps.Count) apps in: $($Category -join ', ')..." -ForegroundColor Cyan
$planItems = @(Get-DevInstallPlan -App $apps -IsInstalled $isInstalled -InstallRoot $InstallRoot)

# --- Show the plan -------------------------------------------------------------
foreach ($item in $planItems) {
    $where = if ($item.Location) { "  -> $($item.Location)" } else { '' }
    if ($item.Action -eq 'skip') { Write-Host ("  ok   {0}" -f $item.App.name) -ForegroundColor DarkGray }
    else { Write-Host ("  +    {0} ({1}: {2}){3}" -f $item.App.name, $item.App.manager, $item.App.id, $where) -ForegroundColor Yellow }
}
$toInstall = @($planItems | Where-Object Action -eq 'install')

$needScoop = $toInstall | Where-Object { $_.App.manager -eq 'scoop' }
if ($needScoop -and -not $hasScoop) {
    # We never run a downloaded install script for you; review it and run it yourself
    $scoopDir = if ($InstallRoot) { Join-Path $InstallRoot 'scoop' } else { "$env:USERPROFILE\scoop" }
    Write-Host "`nScoop is needed for $(@($needScoop).Count) app(s) but is not installed. Install it, then re-run:" -ForegroundColor Yellow
    Write-Host "  irm get.scoop.sh -OutFile `$env:TEMP\install-scoop.ps1"
    Write-Host "  & `$env:TEMP\install-scoop.ps1 -ScoopDir '$scoopDir'"
    $toInstall = @($toInstall | Where-Object { $_.App.manager -ne 'scoop' })
}

$cacheVars = if ($CacheRoot) { Get-DevCacheSetting -CacheRoot $CacheRoot } else { @{} }
foreach ($name in $cacheVars.Keys) {
    if ([Environment]::GetEnvironmentVariable($name, 'User') -ne $cacheVars[$name]) {
        Write-Host ("  ~    set {0} = {1}" -f $name, $cacheVars[$name]) -ForegroundColor Yellow
    }
}

if ($Plan) { Write-Host "`nPlan only - nothing was changed. Run again without -Plan to apply." -ForegroundColor Cyan; return }

# --- Apply ---------------------------------------------------------------------
if ($hasScoop -and ($toInstall | Where-Object { $_.App.manager -eq 'scoop' })) {
    # Make sure every bucket we use is added (main is there by default)
    $buckets = $toInstall | Where-Object { $_.App.manager -eq 'scoop' } | ForEach-Object { ($_.App.id -split '/')[0] } | Sort-Object -Unique
    $have = @(scoop bucket list | ForEach-Object Name)
    foreach ($b in $buckets) { if ($b -notin $have) { scoop bucket add $b } }
}

$failed = @()
foreach ($item in $toInstall) {
    $cmd = Get-DevInstallCommand -PlanItem $item
    Write-Host "`n>> $($item.App.name)" -ForegroundColor Green
    & $cmd.Exe @($cmd.Args)
    if ($LASTEXITCODE -ne 0) { $failed += $item.App.name }
}

foreach ($name in $cacheVars.Keys) {
    New-Item -ItemType Directory -Force -Path $cacheVars[$name] | Out-Null
    [Environment]::SetEnvironmentVariable($name, $cacheVars[$name], 'User')
}

Write-Host ''
if ($failed) { Write-Host "Finished with problems in: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host 'All done. Open a new terminal so PATH and environment changes take effect.' -ForegroundColor Green
