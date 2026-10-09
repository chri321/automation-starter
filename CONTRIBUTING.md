# Contributing

Thanks for considering a contribution. This project is deliberately small, so the
process is short.

## Prerequisites

| Tool | Version | Purpose |
| :--- | :--- | :--- |
| Python | 3.9+ | `pre-commit` and the Python-based hook environments |
| Git | any recent | Hooks are installed as a git hook |
| ShellCheck | 0.11.0 | Installed automatically by `pre-commit`; no manual step needed |
| `gh` CLI | optional | Convenient for opening pull requests |

## Setup

```bash
git clone https://github.com/chri321/automation-starter.git
cd automation-starter
pip install pre-commit
pre-commit install          # runs the hook set on every commit
```

On Windows and macOS, tell git not to fold filename case — `lib/common.sh` and
`lib/common.ps1` differ only by extension and case-folding causes confusing
renames:

```bash
git config core.ignorecase false
```

## Development loop

```bash
pre-commit run --all-files     # full check, the same command CI runs
pre-commit autoupdate          # refresh hook revisions (do this in its own commit)
```

To exercise the reference scripts directly:

```bash
sh examples/demo.sh world
sh examples/demo.sh --dry-run --verbose alice bob
python examples/cleanup.py --dir . --days 0 --dry-run

# Windows delegation chain
powershell -NoProfile -ExecutionPolicy Bypass -File .\examples\demo.ps1 world
cmd /c examples\demo.bat world
```

## Definition of done

Before opening a pull request, all of the following must hold:

1. `pre-commit run --all-files` passes with no failures.
2. Any `.sh` change is clean under `shellcheck --shell=sh --severity=info`.
   Warning-level is the CI gate; info-level is the bar for this project.
3. Any `.ps1` change is clean under `PSScriptAnalyzer` if you have it installed.
4. Documentation is updated in the same pull request as the behaviour change —
   including `CHANGELOG.md` when the change is user-visible.
5. No temporary or debug artefacts are committed. Put scratch files in `.tmp/`,
   which is already ignored.

## Commit messages

This project follows [Conventional Commits](https://www.conventionalcommits.org/).
Commit messages are written in **English**.

```text
<type>(<optional scope>): <description>

<optional body>

<optional footer>
```

Common types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`.

```text
fix(lib): normalise Windows paths before handing them to sh

MSYS treats a backslash as an escape character, so 'D:\repo\task.sh'
reached the child shell as 'D:repotask.sh' and failed with exit 127.
```

## Language conventions

- **Code, comments, commit messages and internal documentation: English.**
- **User-facing documentation: both languages.** `README.md` is the canonical
  English reference; `README_zh-CN.md` is the Simplified Chinese translation.
  Update both in the same pull request.

## Adding a hook

1. Add the `repo` block to `.pre-commit-config.yaml`.
2. **Verify the `rev` first.** Never guess a version — check the upstream releases
   page or `https://api.github.com/repos/<owner>/<repo>/releases/latest` and use a
   real tag.
3. Prefer hooks that need no system binary. If a binary is required, add it to the
   commented "optional hooks" block instead of the active set, and document the
   install command in both README files.
4. Run `pre-commit run --all-files` and confirm the hook actually executes rather
   than silently skipping.

## Adding or changing a shared library function

`lib/common.sh` must stay POSIX-compliant (`sh`, not `bash`) and must remain clean
under `shellcheck --shell=sh --severity=info`. Remember:

- Quote every expansion, use `printf` rather than `echo`, and check commands with
  `command -v` rather than `which`.
- A sourced library must **not** carry a shebang — the
  `check-shebang-scripts-are-executable` hook will correctly reject it.
- Keep logic in `.sh` files. The `.ps1`/`.bat` layers are bridges only and must
  contain no logic.
- Document any `# shellcheck disable=` directive with a reason. Suppressing a
  warning without justification is not accepted.

## Reporting a bug

Please include:

- The exact command you ran.
- The full output, including the exit code.
- Your OS and shell, and the versions from `git --version`, `python --version` and
  `pre-commit --version`.

## License

By contributing you agree that your contributions are licensed under the
[MIT License](LICENSE).
