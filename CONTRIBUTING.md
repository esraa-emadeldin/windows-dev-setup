# Contributing

Thanks for helping! Suggestions for apps are the most useful contribution.

## Suggesting or adding an app

An app belongs here if it is:

1. **Useful to many developers** on Windows (not a niche personal favourite).
2. **Free** (open source preferred) and installable with winget, Scoop or the Microsoft Store.
3. **Not a duplicate** of something already in the same category, unless it's clearly better
   (then propose replacing it).

To add one, edit `catalog.json`:

- Write a short, honest `why`. It's shown to users by `.\setup.ps1 -List`.
- Add a `command` if the app has a CLI command, so existing installs are detected.
- Only set `"location": true` if you checked that `winget install --location <dir>` really installs there.
- Add the app's name to the table in `README.md` (a test checks this).

## Before opening a pull request

```powershell
Invoke-Pester ./tests
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
./tools/Test-CatalogIds.ps1
```

Keep code simple and commented. This project is meant to be easy to read for people new to PowerShell.
