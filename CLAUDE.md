# windows-dev-setup — instructions for Claude Code

PowerShell project: a curated catalog of Windows developer apps (`catalog.json`) and a
plan/apply installer (`setup.ps1`). Logic lives in `src/DevSetup.psm1` as pure functions;
`setup.ps1` does the real installing.

## Commands

- Test: `Invoke-Pester ./tests` (Pester 6.2.0)
- Lint: `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1`
- Check ids still exist: `./tools/Test-CatalogIds.ps1`
- Try it safely: `./setup.ps1 -Category all -Plan`

## Rules

- Never run `setup.ps1` without `-Plan` unless the user asks: it installs software.
- Keep functions in `src/` pure (no installs, no env changes) so they stay testable.
- New app → `catalog.json` + README table; verify the id with `winget show` / `scoop info`.
- Open-source repo: no emails or local machine paths in files (the public GitHub repo URL is fine).
- Note user-visible changes in `CHANGELOG.md` under "Unreleased".
- After changing setup.ps1 output, re-render the README image: `./tools/New-Screenshot.ps1`.
- Keep code simple and commented. Add a test when behaviour changes; run tests + lint before saying it's done.
- Commits: short, simple one-line messages. No Co-Authored-By or any attribution trailer.
