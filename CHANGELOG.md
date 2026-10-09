# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing yet.

## [0.1.0] - 2026-10-10

Initial release.

### Added

- **Hook configuration** (`.pre-commit-config.yaml`) with five hook groups
  covering file hygiene, ShellCheck (POSIX and Bash variants), yamllint, ruff and
  secret detection. All revisions are real upstream release tags verified against
  the GitHub API.
- **`lib/common.sh`** — a POSIX shell shared library providing levelled logging,
  composable argument parsing, a dry-run-aware command runner, a project-root
  guard, CI detection and automatic temporary-directory cleanup on `EXIT`, `INT`
  and `TERM`.
- **`lib/common.ps1`** — the PowerShell forwarding primitive that implements the
  mandated `task.bat` → `task.ps1` → `task.sh` delegation pattern.
- **Reference implementations** — `examples/demo.sh`, `examples/demo.ps1`,
  `examples/demo.bat` and `examples/cleanup.py`.
- **Style configuration** — `.editorconfig`, `.gitattributes`, `.shellcheckrc`,
  `.yamllint.yml`, `PSScriptAnalyzerSettings.psd1`, `ruff.toml`, `.gitignore`.
- **CI workflow** (`.github/workflows/ci.yml`) running the hook set on
  `ubuntu-latest`, `windows-latest` and `macos-latest` with `fail-fast: false`.
- **Documentation** — `README.md` (English, canonical), `README_zh-CN.md`
  (Simplified Chinese), `CONTRIBUTING.md` and this changelog.
- **MIT licence** with attribution to the upstream template.

### Fixed

Both defects below were introduced and caught during the pre-release verification
pass, and are recorded because they are easy to reintroduce.

- **A shebang on a sourced library.** `lib/common.sh` carried `#!/usr/bin/env sh`
  while never being meant for direct execution. The
  `check-shebang-scripts-are-executable` hook correctly rejected it; the shebang
  was removed, since a shebang is a promise that a file can be run directly.
- **Wrong POSIX shell selected on Windows.** Falling back to `Get-Command bash`
  frequently resolves to the Microsoft Store execution alias
  `%LOCALAPPDATA%\Microsoft\WindowsApps\bash.exe` — the WSL stub, not Git Bash.
  It mounts drives at `/mnt/<drive>` and requires an installed distribution, so
  the delegation chain failed with a bare `exit 127` and
  `No such file or directory` for a file that existed. Shell selection now
  explicitly prefers Git for Windows' `sh.exe`, and the script path is converted
  according to the detected shell family (`msys` → `/d/`, `wsl` → `/mnt/d/`,
  `posix` → unchanged).

### Changed

- **`"on":` is quoted in the CI workflow.** YAML 1.1 resolves a bare `on` key to
  boolean true, and this repository's strict yamllint `truthy` rule checks keys as
  well as values, which rejects every GitHub Actions workflow. Quoting keeps the
  strict rule enabled rather than relaxing it.

[Unreleased]: https://github.com/chri321/automation-starter/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/chri321/automation-starter/releases/tag/v0.1.0
