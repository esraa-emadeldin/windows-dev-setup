# Security Policy

This project installs software, so security matters. Things we care about most:

- `setup.ps1` must never download and run a script on its own (no `irm ... | iex`).
- Apps are only installed from winget, the Microsoft Store or Scoop buckets (which verify hashes).
- A catalog entry must never point at a renamed, hijacked or malicious package.

## Reporting a vulnerability

Please **do not open a public issue**. Report it privately instead:
[open a private security advisory](https://github.com/esraa-emadeldin/windows-dev-setup/security/advisories/new).

Include what you found, how to reproduce it, and which version (commit) you used.
You should get a first reply within 7 days.

## Supported versions

Only the latest commit on `main` is supported.
