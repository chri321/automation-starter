# automation-starter

[![CI](https://github.com/chri321/automation-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/chri321/automation-starter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://pre-commit.com)
[![Platforms](https://img.shields.io/badge/platforms-Linux%20%7C%20macOS%20%7C%20Windows-blue)](#requirements)
[![Python](https://img.shields.io/badge/python-3.9%2B-blue?logo=python)](https://www.python.org)

[English](README.md) | [简体中文](README_zh-CN.md)

A lightweight, cross-platform starter kit for **automation-script repositories** —
the kind of repo that is mostly Shell, PowerShell and Python glue rather than an
application. Clone it, or copy the parts you want, and get linting, formatting,
line-ending normalisation and secret scanning from a single `pre-commit` install.

No toolchain orchestrator to adopt, no polyglot runtime matrix to download. The
only thing you install globally is `pre-commit` itself.

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Usage](#usage)
  - [Shell scripts](#shell-scripts)
  - [The `lib/common.sh` API](#the-libcommonsh-api)
  - [Python scripts](#python-scripts)
  - [Cross-platform wrappers](#cross-platform-wrappers)
- [Project structure](#project-structure)
- [Configuration](#configuration)
  - [Active hooks](#active-hooks)
  - [Optional hooks](#optional-hooks)
- [Continuous integration](#continuous-integration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## Features

- **One dependency.** Hooks resolve to standard upstream repositories that
  `pre-commit` installs into its own isolated virtualenvs. Nothing else to install.
- **ShellCheck-clean POSIX shell.** A working shared library (`lib/common.sh`)
  providing logging, argument parsing, a dry-run-aware command runner, a project-root
  guard and automatic temporary-directory cleanup.
- **A real cross-platform bridge.** `task.bat` → `task.ps1` → `task.sh` delegation,
  where only the `.sh` file holds logic. Handles the two Windows traps that
  silently break such bridges (see [Acknowledgements](#acknowledgements)).
- **Line endings pinned per platform.** `.gitattributes` forces LF for `*.sh` and
  CRLF for `*.ps1`/`*.bat`, so a script never fails on Linux with `sh\r`.
- **Secret scanning ready.** A ready-to-enable `gitleaks` hook, because hard-coded
  tokens are the classic automation-script mistake.
- **Pinned, verified revisions.** Every hook `rev` is a real upstream release tag
  confirmed against the GitHub API — nothing guessed.

## Requirements

| Requirement | Version | Notes |
| :--- | :--- | :--- |
| Python | 3.9+ | `pre-commit` and the Python-based hook environments |
| Git | any recent | The kit is installed as a git hook |
| POSIX shell | any | Git for Windows ships `sh`; nothing extra needed on Linux/macOS |
| PowerShell | 5.1+ | Only for the optional `.ps1` wrapper layer |

Optional tools, only if you enable their hooks: `shfmt`, `PSScriptAnalyzer`
(PowerShell module), `gitleaks`.

## Installation

```bash
git clone https://github.com/chri321/automation-starter.git
cd automation-starter
pip install pre-commit
pre-commit install
```

To adopt the kit inside an **existing** repository, copy the files you need and
skip the clone:

```bash
# Minimum useful set
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.pre-commit-config.yaml
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.shellcheckrc
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.editorconfig
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.gitattributes
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.yamllint.yml
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/ruff.toml
pre-commit install
```

## Quick start

```bash
pip install pre-commit          # 1. install the only global dependency
pre-commit install              # 2. activate the git hook in this repository
pre-commit run --all-files      # 3. check everything now
```

That is the whole setup. From here on the hooks run automatically on `git commit`.

## Usage

### Shell scripts

Start every script from this skeleton:

```sh
set -eu                                    # NOT `pipefail` - unsupported by POSIX sh

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"              # adjust the relative path as needed

PROG_NAME=$(basename "$0")

usage() {
    cat <<EOF
Usage: $PROG_NAME [OPTIONS] <args>
EOF
}

main() {
    # Common flags are consumed by the library; your own flags belong in the case.
    while [ $# -gt 0 ]; do
        if parse_common_arg "$1"; then shift; continue; fi
        case "$1" in
            --) shift; break ;;
            -*) log_error "unknown option: $1"; usage >&2; exit 2 ;;
            *)  break ;;
        esac
    done

    guard_project_root                     # refuse to run from the wrong directory
    work_dir=$(make_tmpdir)                # created lazily, removed on exit
    run rm -rf "$stale_dir"                # prints instead of executing under --dry-run
    log_success 'done'
    print_next_actions 'Run: pre-commit run --all-files'
}

main "$@"
```

### The `lib/common.sh` API

| Function | Description |
| :--- | :--- |
| `log_info` / `log_success` / `log_warn` / `log_error` | Levelled logging. Colour is dropped when stdout is not a TTY or `NO_COLOR` is set. Warnings and errors go to stderr. |
| `log_debug` | Emitted only under `-v`, and **always to stderr** so it cannot corrupt `$(...)`. |
| `die "message"` | Report an error and exit non-zero. |
| `has_cmd` / `require_cmd` | Command detection via `command -v`, never `which`. |
| `is_ci_env` | True when `CI` or `GITHUB_ACTIONS` is set. |
| `make_tmpdir` | Lazily create a temporary directory; removed automatically on `EXIT`, `INT` and `TERM`. |
| `run <cmd...>` | Execute a command, honouring `--dry-run` and `--verbose`. |
| `guard_project_root` | Verify a root marker (default `.git`; override with `PROJECT_ROOT_MARKER`). |
| `parse_common_arg "$1"` | Recognise `-v`, `-n`, `-h`. **Returns 0 when it consumed the argument.** |
| `print_next_actions '...'` | Print a standard closing prompt. |

> **Why `parse_common_arg` and not `parse_common_args "$@"`?**
> POSIX shell has no arrays, so a helper physically cannot hand an arbitrary
> `argv` back to its caller. This one reports whether it consumed the current
> argument and leaves the caller in charge of its own loop. That is the correct
> design for POSIX sh, not a shortcut.

### Python scripts

`examples/cleanup.py` is the reference: `argparse` with `--dry-run` as a
first-class option, `pathlib` instead of `os.path` string juggling, a `main()`
guarded by `if __name__ == "__main__":`, and explicit exit codes.

```bash
python examples/cleanup.py --dir ./logs --days 30 --dry-run
ruff check examples/cleanup.py
```

### Cross-platform wrappers

For scripts that must also run on Windows, use the three-file delegation chain.
**All logic lives in the `.sh` file**; the wrappers only forward.

```text
task.bat   ->   task.ps1   ->   task.sh
(CMD entry)     (PS entry)     (POSIX logic, single source of truth)
```

```powershell
# task.ps1
. "$PSScriptRoot/../lib/common.ps1"
Invoke-ShellDelegation (Join-Path $PSScriptRoot 'task.sh') $args
```

```bat
REM task.bat
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0task.ps1" %*
```

`Invoke-ShellDelegation` locates a POSIX shell, converts the script path into the
form that shell expects, forwards your arguments and propagates the exit code.

## Project structure

```text
automation-starter/
├── .github/
│   └── workflows/
│       └── ci.yml                 # three-OS pre-commit matrix
├── examples/
│   ├── cleanup.py                 # Python reference implementation
│   ├── demo.sh                    # Shell reference implementation
│   ├── demo.ps1                   # thin PowerShell wrapper
│   └── demo.bat                   # thin CMD wrapper
├── lib/
│   ├── common.sh                  # POSIX shell shared library
│   └── common.ps1                 # PowerShell delegation helper
├── .editorconfig                  # indent / EOL / encoding standards
├── .gitattributes                 # per-platform line endings
├── .gitignore
├── .pre-commit-config.yaml        # the hook set
├── .shellcheckrc                  # ShellCheck configuration
├── .yamllint.yml                  # YAML rules
├── PSScriptAnalyzerSettings.psd1  # PowerShell analysis settings
├── ruff.toml                      # Python lint rules
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE                        # MIT, verbatim so detection tools match it
├── NOTICE                         # attribution for the derived configuration layer
├── README.md                      # this file (canonical)
└── README_zh-CN.md                # Simplified Chinese translation
```

## Configuration

### Active hooks

| Hook | Purpose |
| :--- | :--- |
| `trailing-whitespace`, `end-of-file-fixer`, `mixed-line-ending` | File hygiene. `mixed-line-ending` reports but never rewrites, because `.gitattributes` owns line endings. |
| `fix-byte-order-marker` | Strip UTF-8 BOMs, matching `.editorconfig`. |
| `check-merge-conflict`, `check-case-conflict` | Catch leftover conflict markers and case-colliding filenames. |
| `check-symlinks`, `destroyed-symlinks` | Detect broken and clobbered symlinks. |
| `check-added-large-files` | Block accidental binaries over 1 MB. |
| `check-executables-have-shebangs`, `check-shebang-scripts-are-executable` | Keep the shebang/executable-bit contract honest in both directions. |
| `detect-private-key` | Block committed private keys. |
| `shellcheck` (POSIX and Bash variants) | Shell static analysis. |
| `yamllint` | YAML validation against [`.yamllint.yml`](.yamllint.yml). |
| `ruff`, `ruff-format` | Python lint and format. |

### Optional hooks

Disabled by default because each needs a binary or module on your machine. Install
the tool, then uncomment the matching block in
[`.pre-commit-config.yaml`](.pre-commit-config.yaml).

```bash
# shfmt - shell formatting
go install mvdan.cc/sh/v3/cmd/shfmt@latest

# PSScriptAnalyzer - PowerShell static analysis
pwsh -Command 'Install-Module -Name PSScriptAnalyzer -Scope CurrentUser'

# gitleaks - secret scanning on commit
winget install gitleaks        # Windows
brew install gitleaks          # macOS
```

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the same hook set on
`ubuntu-latest`, `windows-latest` and `macos-latest` with `fail-fast: false`, so a
platform-specific regression is visible rather than masked. Running on three
platforms is the point: line-ending and shell-selection bugs only appear on some
of them.

## Verification

This kit was tested rather than assumed. Evidence:

| Check | Result |
| :--- | :--- |
| `pre-commit validate-config` | exit 0 |
| `pre-commit run --all-files` | all 17 hooks pass, exit 0 |
| `shellcheck --shell=sh` on `lib/common.sh` and `demo.sh` | zero findings at both `warning` and `info` severity |
| `yamllint` using this repository's own strict config | exit 0 |
| `ruff check` and `ruff format --check` | pass, already formatted |
| `demo.sh` normal / no args / bad args / `--help` / `--dry-run` | exit 0 / 2 / 2 / 0 / 0 |
| `demo.ps1` and `demo.bat` delegation chain | exit 0, correct output |

Tested against pre-commit 4.6.2, ShellCheck 0.11.0, yamllint 1.38.0, ruff 0.16.10
and gitleaks 8.30.1.

Two real defects were found and fixed by this process; both are documented in the
[CHANGELOG](CHANGELOG.md).

## Troubleshooting

| Symptom | Cause and fix |
| :--- | :--- |
| `check-shebang-scripts-are-executable` fails | The executable bit was lost when files were copied: `git add --chmod=+x '*.sh'`. Only for scripts meant to run directly — a **sourced** library must have no shebang at all. |
| `exit 127` with `No such file or directory` for a file that exists | The delegation helper selected the wrong shell or path form. On Windows, `Get-Command bash` often resolves to the WSL stub in `%LOCALAPPDATA%\Microsoft\WindowsApps`, which mounts drives at `/mnt/d`. `Get-PosixShell` handles this; make sure it reports Git's `sh.exe` with `Family=msys`. |
| `mixed line ending` fails but does not auto-fix | Intentional (`--fix=no`). `.gitattributes` owns line endings; letting the hook rewrite files would fight the CRLF rules it enforces. |
| yamllint: `truthy value should be one of [false, true]` pointing at `on:` | YAML 1.1 resolves a bare `on` to boolean true, and this repository's strict `truthy` rule checks keys as well as values. Quote the key: `"on":`. GitHub Actions accepts both forms. |
| yamllint demands a `---` document start | `document-start: present` is enabled. Add `---` to new YAML files. |
| `Attempt to write a readonly database` | A `pre-commit` cache permission problem, typically seen in sandboxes. Not an issue in a normal environment. |
| `git` cannot reach github.com | In networks where github.com is SNI-blocked, route git through your local proxy, scoped to GitHub only: `git config --global http.https://github.com.proxy http://127.0.0.1:7890` |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: conventional commit messages,
hooks must pass, and every script change must keep `shellcheck --shell=sh` clean
at `--severity=info`.

## License

[MIT](LICENSE) © 2026 chri321.

## Acknowledgements

The configuration layer (`.editorconfig`, `.gitattributes`, `.shellcheckrc`,
`.yamllint.yml`, `PSScriptAnalyzerSettings.psd1`, `ruff.toml` and the hook set) is
adapted from [snowdreamtech/template](https://github.com/snowdreamtech/template),
also MIT licensed. The required attribution is recorded in [`NOTICE`](NOTICE);
[`LICENSE`](LICENSE) is kept as the unmodified MIT text so that licence-detection
tools recognise it. That project's `.agent/rules/shell.md` is an excellent
practical reference for writing robust shell and is worth reading in full.

Two things this kit does differently, both learned the hard way while testing:

1. **Upstream forbids a shebang on the shared library transitively.** Its
   `check-shebang-scripts-are-executable` hook is right to complain about a sourced
   file carrying a shebang; this kit makes that explicit.
2. **Blindly falling back to `bash` on Windows is a trap.** The Microsoft Store
   execution alias is a WSL stub, not Git Bash, and it fails with a bare exit 127.
