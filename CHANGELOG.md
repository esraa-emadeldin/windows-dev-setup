# Changelog

All notable changes to this project. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] - 2026-11-18

### Added
- Catalog of 45 developer apps in 13 categories, each with a one-line "why".
- `setup.ps1` with `-List`, `-Plan`, `-Category`, `-InstallRoot`, `-CacheRoot`, `-CatalogPath`.
- Skips apps that winget/Scoop already manage **or** whose command is already on PATH.
- Pester tests, PSScriptAnalyzer lint and GitHub Actions CI (incl. a Windows PowerShell 5.1 smoke test).
- `tools/Test-CatalogIds.ps1` to check every package id still exists.
- `tools/New-Screenshot.ps1` to render the README screenshot from a real run.

### Changed
- `-Plan` is about 10x faster: winget and Scoop are asked once instead of once per app.

### Fixed
- Works on Windows PowerShell 5.1 (`$PSScriptRoot` in a parameter default).
- `-Category core,web` works when started with `powershell -File`.

[Unreleased]: https://github.com/esraa-emadeldin/windows-dev-setup/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/esraa-emadeldin/windows-dev-setup/releases/tag/v0.1.0
