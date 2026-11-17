## What does this change?

<!-- One or two sentences. For a new app: name, id, category and why. -->

## Checklist

- [ ] `Invoke-Pester ./tests` passes
- [ ] `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` shows no issues
- [ ] New/changed apps: id checked with `winget show` / `scoop info` (or `./tools/Test-CatalogIds.ps1`)
- [ ] New apps are also in the README table
- [ ] `CHANGELOG.md` updated under "Unreleased"
