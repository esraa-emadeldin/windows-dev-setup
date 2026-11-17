# Pester tests. Run with:  Invoke-Pester ./tests
# They never install anything: "is it installed?" is faked with a scriptblock.

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $root 'src/DevSetup.psm1') -Force

    # A tiny catalog used by most tests
    $script:mini = [pscustomobject]@{
        categories = [pscustomobject]@{ core = 'Core'; web = 'Web' }
        apps       = @(
            [pscustomobject]@{ category = 'core'; manager = 'winget';  id = 'Git.Git';      name = 'Git';     location = $true;  why = 'vcs' }
            [pscustomobject]@{ category = 'core'; manager = 'scoop';   id = 'main/fzf';     name = 'fzf';                        why = 'find' }
            [pscustomobject]@{ category = 'web';  manager = 'winget';  id = 'OpenJS.NodeJS'; name = 'Node.js'; location = $false; why = 'js' }
            [pscustomobject]@{ category = 'web';  manager = 'msstore'; id = '9ABC';         name = 'Store App';                  why = 'store' }
        )
    }
}

Describe 'The real catalog.json' {
    BeforeAll { $script:catalog = Get-DevCatalog -Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'catalog.json') }

    It 'has no problems' {
        $problems = Test-DevCatalog -Catalog $catalog
        $problems -join "`n" | Should -BeNullOrEmpty
    }

    It 'lists every app in the README table (so docs and catalog never drift apart)' {
        $readme = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'README.md') -Raw
        foreach ($app in $catalog.apps) {
            $readme | Should -Match ([regex]::Escape($app.name)) -Because "README should mention '$($app.name)'"
        }
    }

    It 'has at least one app in every category' {
        foreach ($cat in $catalog.categories.PSObject.Properties.Name) {
            @($catalog.apps | Where-Object category -eq $cat).Count | Should -BeGreaterThan 0 -Because "category '$cat' should not be empty"
        }
    }
}

Describe 'Test-DevCatalog' {
    It 'accepts a valid catalog' {
        (Test-DevCatalog -Catalog $mini).Count | Should -Be 0
    }

    It 'reports missing fields, bad manager, unknown category, bad scoop id and duplicates' {
        $bad = [pscustomobject]@{
            categories = [pscustomobject]@{ core = 'Core' }
            apps       = @(
                [pscustomobject]@{ category = 'core';  manager = 'winget'; id = 'A.A'; name = 'A' }                    # no 'why'
                [pscustomobject]@{ category = 'core';  manager = 'choco';  id = 'B.B'; name = 'B'; why = 'x' }        # bad manager
                [pscustomobject]@{ category = 'games'; manager = 'winget'; id = 'C.C'; name = 'C'; why = 'x' }        # bad category
                [pscustomobject]@{ category = 'core';  manager = 'scoop';  id = 'fzf'; name = 'fzf'; why = 'x' }      # no bucket
                [pscustomobject]@{ category = 'core';  manager = 'winget'; id = 'A.A'; name = 'A2'; why = 'x' }       # duplicate
            )
        }
        $text = (Test-DevCatalog -Catalog $bad) -join "`n"
        $text | Should -Match "A.A: missing 'why'"
        $text | Should -Match "unknown manager 'choco'"
        $text | Should -Match "unknown category 'games'"
        $text | Should -Match "bucket/app"
        $text | Should -Match 'listed twice'
    }

    It "rejects a 'command' that is a path instead of a plain name" {
        $bad = [pscustomobject]@{
            categories = [pscustomobject]@{ core = 'Core' }
            apps       = @([pscustomobject]@{ category = 'core'; manager = 'winget'; id = 'A.A'; name = 'A'; why = 'x'; command = 'C:\tools\a.exe' })
        }
        (Test-DevCatalog -Catalog $bad) -join "`n" | Should -Match 'plain command name'
    }
}

Describe 'Select-DevApp' {
    It 'returns only apps in the chosen categories' {
        $apps = Select-DevApp -Catalog $mini -Category 'web'
        $apps.name | Should -Be @('Node.js', 'Store App')
    }

    It "accepts 'core,web' as one string (how powershell -File passes it)" {
        (Select-DevApp -Catalog $mini -Category 'core, web').Count | Should -Be 4
    }

    It "treats 'all' as every category" {
        (Select-DevApp -Catalog $mini -Category 'all').Count | Should -Be 4
    }

    It 'throws a helpful error for an unknown category' {
        { Select-DevApp -Catalog $mini -Category 'games' } | Should -Throw '*Unknown category: games*'
    }
}

Describe 'Get-DevInstallPlan' {
    It 'skips installed apps and installs the rest' {
        $installedIds = @('Git.Git')
        $plan = Get-DevInstallPlan -App $mini.apps -IsInstalled { param($a) $a.id -in $installedIds }
        ($plan | Where-Object { $_.App.id -eq 'Git.Git' }).Action | Should -Be 'skip'
        @($plan | Where-Object Action -eq 'install').Count | Should -Be 3
    }

    It 'uses InstallRoot only for winget apps that support a custom location' {
        $plan = Get-DevInstallPlan -App $mini.apps -IsInstalled { $false } -InstallRoot 'D:\Tools'
        ($plan | Where-Object { $_.App.id -eq 'Git.Git' }).Location       | Should -Be 'D:\Tools\Git'
        ($plan | Where-Object { $_.App.id -eq 'OpenJS.NodeJS' }).Location | Should -BeNullOrEmpty
        ($plan | Where-Object { $_.App.id -eq 'main/fzf' }).Location      | Should -BeNullOrEmpty
    }

    It 'has no location when InstallRoot is not given' {
        $plan = Get-DevInstallPlan -App $mini.apps -IsInstalled { $false }
        @($plan | Where-Object Location).Count | Should -Be 0
    }

    It 'handles an empty app list' {
        @(Get-DevInstallPlan -App @() -IsInstalled { $false }).Count | Should -Be 0
    }
}

Describe 'Get-DevInstallCommand' {
    It 'builds a winget command with --location when there is one' {
        $item = [pscustomobject]@{ App = $mini.apps[0]; Action = 'install'; Location = 'D:\Tools\Git' }
        $cmd = Get-DevInstallCommand -PlanItem $item
        $cmd.Exe | Should -Be 'winget'
        $cmd.Args | Should -Contain '--location'
        $cmd.Args | Should -Contain 'D:\Tools\Git'
        $cmd.Args[$cmd.Args.IndexOf('--source') + 1] | Should -Be 'winget'
    }

    It 'uses the msstore source for Store apps' {
        $item = [pscustomobject]@{ App = $mini.apps[3]; Action = 'install'; Location = $null }
        $cmd = Get-DevInstallCommand -PlanItem $item
        $cmd.Args[$cmd.Args.IndexOf('--source') + 1] | Should -Be 'msstore'
        $cmd.Args | Should -Not -Contain '--location'
    }

    It 'builds a scoop command for scoop apps' {
        $item = [pscustomobject]@{ App = $mini.apps[1]; Action = 'install'; Location = $null }
        $cmd = Get-DevInstallCommand -PlanItem $item
        $cmd.Exe | Should -Be 'scoop'
        $cmd.Args | Should -Be @('install', 'main/fzf')
    }
}

Describe 'ConvertFrom-DevInstalledExport' {
    BeforeAll {
        # Same shape as real `winget export` / `scoop export` output
        $script:wingetJson = '{"Sources":[{"Packages":[{"PackageIdentifier":"Git.Git"}],"SourceDetails":{"Name":"winget"}},
                                           {"Packages":[{"PackageIdentifier":"9ABC"}],"SourceDetails":{"Name":"msstore"}}]}'
        $script:scoopJson  = '{"buckets":[{"Name":"main"}],"apps":[{"Name":"fzf","Source":"main"}]}'
    }

    It 'collects ids from every winget source, case-insensitively' {
        $set = ConvertFrom-DevInstalledExport -WingetJson $wingetJson -ScoopJson ''
        $set.Winget.Contains('git.git') | Should -BeTrue
        $set.Winget.Contains('9ABC')    | Should -BeTrue
        $set.Scoop.Count                | Should -Be 0
    }

    It 'collects Scoop app names' {
        $set = ConvertFrom-DevInstalledExport -WingetJson '' -ScoopJson $scoopJson
        $set.Scoop.Contains('fzf') | Should -BeTrue
    }
}

Describe 'Test-DevAppInstalled' {
    BeforeAll {
        $script:installed = ConvertFrom-DevInstalledExport `
            -WingetJson '{"Sources":[{"Packages":[{"PackageIdentifier":"Git.Git"}]}]}' `
            -ScoopJson  '{"apps":[{"Name":"fzf"}]}'
        $script:noCommands = { $false }
    }

    It 'finds winget apps by id and scoop apps by name (bucket ignored)' {
        Test-DevAppInstalled -App $mini.apps[0] -Installed $installed -CommandExists $noCommands | Should -BeTrue   # Git.Git
        Test-DevAppInstalled -App $mini.apps[1] -Installed $installed -CommandExists $noCommands | Should -BeTrue   # main/fzf
        Test-DevAppInstalled -App $mini.apps[2] -Installed $installed -CommandExists $noCommands | Should -BeFalse  # Node.js
    }

    It "treats an app as installed when its command already exists (no duplicate copies)" {
        $app = [pscustomobject]@{ manager = 'scoop'; id = 'main/ripgrep'; command = 'rg' }
        Test-DevAppInstalled -App $app -Installed $installed -CommandExists { param($n) $n -eq 'rg' } | Should -BeTrue
        Test-DevAppInstalled -App $app -Installed $installed -CommandExists $noCommands | Should -BeFalse
    }
}

Describe 'Get-DevCacheSetting' {
    It 'puts every cache under the given root' {
        $vars = Get-DevCacheSetting -CacheRoot 'D:\Cache'
        $vars['PIP_CACHE_DIR'] | Should -Be 'D:\Cache\pip'
        foreach ($value in $vars.Values) { $value | Should -BeLike 'D:\Cache\*' }
    }
}
