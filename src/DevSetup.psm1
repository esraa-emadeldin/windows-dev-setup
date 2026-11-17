# DevSetup.psm1 - the "thinking" part of windows-dev-setup.
# Every function here is pure: it only reads data and returns data, it never
# installs anything. That keeps it easy to test (see tests/DevSetup.Tests.ps1).
# setup.ps1 does the actual installing.

$ValidManagers = @('winget', 'scoop', 'msstore')

function Get-DevCatalog {
    <# Reads catalog.json and returns it as an object with .categories and .apps #>
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { throw "Catalog not found: $Path" }
    return Get-Content $Path -Raw | ConvertFrom-Json
}

function Test-DevCatalog {
    <# Returns a list of problems in the catalog (empty list = catalog is OK) #>
    param([Parameter(Mandatory)]$Catalog)
    $problems = [System.Collections.Generic.List[string]]::new()
    $categories = @($Catalog.categories.PSObject.Properties.Name)
    $seen = @{}

    foreach ($app in $Catalog.apps) {
        $label = if ($app.id) { $app.id } else { '<no id>' }
        foreach ($field in 'id', 'name', 'manager', 'category', 'why') {
            if (-not $app.$field) { $problems.Add("${label}: missing '$field'") }
        }
        if ($app.manager -and $app.manager -notin $ValidManagers) {
            $problems.Add("${label}: unknown manager '$($app.manager)' (use $($ValidManagers -join ', '))")
        }
        if ($app.category -and $app.category -notin $categories) {
            $problems.Add("${label}: unknown category '$($app.category)'")
        }
        # Scoop ids must name their bucket, e.g. main/fzf, so installs are predictable
        if ($app.manager -eq 'scoop' -and $app.id -notmatch '^[\w-]+/[\w.-]+$') {
            $problems.Add("${label}: scoop id must look like 'bucket/app'")
        }
        # Optional 'command': a plain command name used to detect an existing install
        if ($app.command -and $app.command -notmatch '^[\w.-]+$') {
            $problems.Add("${label}: 'command' must be a plain command name like 'rg'")
        }
        if ($app.id) {
            if ($seen.ContainsKey($app.id)) { $problems.Add("${label}: listed twice") }
            $seen[$app.id] = $true
        }
    }
    return , $problems   # the comma keeps an empty list from turning into $null
}

function Select-DevApp {
    <# Picks the apps for the chosen categories. 'all' means every category. #>
    param(
        [Parameter(Mandatory)]$Catalog,
        [Parameter(Mandatory)][string[]]$Category
    )
    $known = @($Catalog.categories.PSObject.Properties.Name)
    if ($Category -contains 'all') { $Category = $known }

    $unknown = $Category | Where-Object { $_ -notin $known }
    if ($unknown) { throw "Unknown category: $($unknown -join ', '). Choose from: $($known -join ', '), all" }

    return @($Catalog.apps | Where-Object { $_.category -in $Category })
}

function Get-DevInstallPlan {
    <#
      Decides what to do with each app: 'skip' if already installed, otherwise 'install'.
      -IsInstalled is a scriptblock that receives the app and returns $true/$false,
      so tests can pass a fake one instead of calling winget/scoop.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$App,
        [Parameter(Mandatory)][scriptblock]$IsInstalled,
        [string]$InstallRoot
    )
    foreach ($a in $App) {
        # Only winget apps marked "location": true honour a custom folder
        $location = $null
        if ($InstallRoot -and $a.manager -eq 'winget' -and $a.location) {
            $location = Join-Path $InstallRoot ($a.name -replace '[^\w.-]', '')
        }
        [pscustomobject]@{
            App      = $a
            Action   = if (& $IsInstalled $a) { 'skip' } else { 'install' }
            Location = $location
        }
    }
}

function Get-DevInstallCommand {
    <# Builds the command (exe + arguments) for one plan item. Returned, not run. #>
    param([Parameter(Mandatory)]$PlanItem)
    $app = $PlanItem.App
    switch ($app.manager) {
        'scoop' {
            return @{ Exe = 'scoop'; Args = @('install', $app.id) }
        }
        default {
            # winget and msstore both go through winget; only the source differs
            $source = if ($app.manager -eq 'msstore') { 'msstore' } else { 'winget' }
            $argList = @('install', '--id', $app.id, '--exact', '--source', $source,
                         '--accept-package-agreements', '--accept-source-agreements')
            if ($PlanItem.Location) { $argList += @('--location', $PlanItem.Location) }
            return @{ Exe = 'winget'; Args = $argList }
        }
    }
}

function Get-DevCacheSetting {
    <#
      Environment variables that move package caches off C:.
      Returns an ordered map of NAME -> folder under $CacheRoot.
    #>
    param([Parameter(Mandatory)][string]$CacheRoot)
    return [ordered]@{
        npm_config_cache = Join-Path $CacheRoot 'npm'     # npm reads npm_config_* env vars
        PIP_CACHE_DIR    = Join-Path $CacheRoot 'pip'
        UV_CACHE_DIR     = Join-Path $CacheRoot 'uv'
        NUGET_PACKAGES   = Join-Path $CacheRoot 'nuget'
        GRADLE_USER_HOME = Join-Path $CacheRoot 'gradle'
    }
}

Export-ModuleMember -Function Get-DevCatalog, Test-DevCatalog, Select-DevApp, Get-DevInstallPlan, Get-DevInstallCommand, Get-DevCacheSetting
