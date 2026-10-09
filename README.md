# automation-starter — 轻量自动化脚本仓库骨架

从 [snowdreamtech/template](https://github.com/snowdreamtech/template) 里**摘取并重做**的一套脚本工程化配置。

目标很具体：让你写 Shell / PowerShell / Python 自动化脚本时，**编辑器里合规、提交时自动拦截、CI 里不翻车**——而不是把一个 88 个规则文件、50 多个 IDE 目录的企业级脚手架搬回家。

## 为什么不是直接用原模板

原模板是给"多语言企业项目 + 多 AI IDE 协作"设计的。对只写自动化脚本的人来说，它有三类问题，这套骨架针对性处理了：

| 原模板的问题 | 这里的处理 |
| :--- | :--- |
| 强绑 `unirtm` 工具链编排器，829 行 pre-commit 配置里全是 `unirtm hook-exec xxx`，脱离它跑不起来 | 全部改成标准上游 hook 仓库，**全局只需装 `pre-commit` 一个东西** |
| 锁了 Go / Node / Python / trivy / syft / goreleaser 一堆用不到的版本，`unirtm install` 要拉一大堆 | 只保留脚本相关配置，零额外运行时依赖 |
| `.agent/rules/shell.md` 强制要求所有脚本 `source lib/common.sh` 并调用 `guard_project_root` / `parse_common_args`，但 **`scripts/lib/` 根本没随仓库发布** | 补上了可用的 `lib/common.sh` 与 `lib/common.ps1` |

原模板对写脚本真正有价值的部分（`shell.md` 那 573 行规范、`.shellcheckrc`、`.gitattributes`、PSScriptAnalyzer 配置）都保留并精简了。

## 快速开始

```bash
# 1. 装 pre-commit（本机已装好：pre-commit 4.6.2）
pip install pre-commit

# 2. 激活 git 钩子（每个仓库执行一次）
cd automation-starter
pre-commit install

# 3. 全量跑一遍
pre-commit run --all-files

# 可选：刷新 hook 版本
pre-commit autoupdate
```

> ⚠️ 目前这个目录已经 `git init` 并 `git add` 了，但**还没有 commit**。建议先提交一次，让 hook 生效。

## 文件清单

| 文件 | 作用 |
| :--- | :--- |
| `.pre-commit-config.yaml` | **核心**。5 组 hook，全部为已验证的真实上游版本 |
| `.shellcheckrc` | ShellCheck 配置。已处理 `SC1091`（动态 source）和 `SC3043`（POSIX 下用 `local`） |
| `.editorconfig` | 缩进/换行/编码标准（sh 2 空格、py 与 ps1 4 空格、md 保留行尾空格） |
| `.gitattributes` | **关键**。`*.sh` 强制 LF、`*.ps1`/`*.bat` 强制 CRLF，避免 Linux 上 `sh\r` 报错 |
| `.yamllint.yml` | YAML 校验，含强制文档头 `---`、2 空格缩进、禁止行尾空格 |
| `ruff.toml` | Python lint（E/F/W/I/N 规则集，行宽 120） |
| `PSScriptAnalyzerSettings.psd1` | PowerShell 静态分析配置（可选启用） |
| `.gitignore` | 排除 `.env`、密钥、`.tmp/`、各类缓存 |
| `lib/common.sh` | **补写的 POSIX Shell 共享库**（原模板缺失） |
| `lib/common.ps1` | **补写的 PowerShell 委托库**（原模板缺失） |
| `examples/demo.sh` | Shell 参考实现：严格模式、库引用、参数解析、dry-run、退出码 |
| `examples/demo.ps1` | 瘦包装器（零逻辑，仅转发） |
| `examples/demo.bat` | CMD 入口（零逻辑，仅转发给 ps1） |
| `examples/cleanup.py` | Python 参考实现：argparse、pathlib、dry-run、显式退出码 |
| `.github/workflows/ci.yml` | GitHub Actions：ubuntu / windows / macos 三平台矩阵跑 pre-commit |
| `LICENSE` | MIT，含对上游 `snowdreamtech/template` 的署名（本项目的配置文件层由其派生） |

## 写新脚本时怎么用

### Shell 脚本

```sh
set -eu                                    # 注意：不用 pipefail，POSIX sh 不支持

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"              # 路径按实际层级调整

usage() { cat <<EOF
Usage: $PROG_NAME [OPTIONS] <args>
EOF
}

main() {
    # 参数解析：公共参数交给库，自己的参数自己管
    while [ $# -gt 0 ]; do
        if parse_common_arg "$1"; then shift; continue; fi
        case "$1" in
            --) shift; break ;;
            -*) log_error "unknown option: $1"; usage >&2; exit 2 ;;
            *)  break ;;
        esac
    done

    guard_project_root                     # 防止在错误目录下执行破坏性操作
    work_dir=$(make_tmpdir)                # 自动创建，退出时自动清理
    run rm -rf "$stale_dir"                # --dry-run 时只打印不执行
    log_success 'done'
    print_next_actions 'Run: pre-commit run --all-files'
}

main "$@"
```

### `lib/common.sh` API

| 函数 | 说明 |
| :--- | :--- |
| `log_info` / `log_success` / `log_warn` / `log_error` | 分级日志，非 TTY 或 `NO_COLOR` 下自动去色；warn/error 走 stderr |
| `log_debug` | 仅 `-v` 时输出，且**始终走 stderr**，不会污染 `$(...)` |
| `die "msg"` | 打印错误并以非零码退出 |
| `has_cmd` / `require_cmd` | 用 `command -v` 判断（不用跨平台行为不一致的 `which`） |
| `is_ci_env` | 判断 `CI` / `GITHUB_ACTIONS` |
| `make_tmpdir` | 惰性创建临时目录，`EXIT`/`INT`/`TERM` 时自动清理 |
| `run <cmd...>` | 尊重 `--dry-run` 与 `--verbose` 的执行包装 |
| `guard_project_root` | 校验根目录标记（默认 `.git`，可用 `PROJECT_ROOT_MARKER` 覆盖） |
| `parse_common_arg "$1"` | 识别 `-v` / `-n` / `-h`，**返回 0 表示已消费** |
| `print_next_actions '...'` | 打印收尾提示 |

> 📌 **`parse_common_arg` 而不是 `parse_common_args`**：POSIX sh 没有数组，辅助函数无法把任意 argv 交还给调用方。所以这里返回"是否已消费该参数"，由调用方保留自己的循环——这是正确做法，不是偷懒。原模板规则里写的 `parse_common_args "$@"` 是一种在 POSIX sh 里实现不了的接口。

### 跨平台三件套

```
task.bat   →   task.ps1   →   task.sh
（CMD 入口）    （PS 入口）      （POSIX 逻辑，唯一事实来源）
```

**逻辑只写在 `.sh` 里**，包装器零逻辑：

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

## 可选 hook

默认关闭，装了对应工具后到 `.pre-commit-config.yaml` 第 5 节取消注释即可：

```bash
# shfmt —— Shell 格式化（会改文件）
# 装法：scoop install shfmt / go install mvdan.cc/sh/v3/cmd/shfmt@latest

# PSScriptAnalyzer —— PowerShell 静态分析
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser

# gitleaks —— 提交时扫描硬编码密钥（自动化脚本最容易踩的坑）
# 装法：scoop install gitleaks
```

## 已验证

不敢只写不测。这套配置在真实环境跑过，实测记录：

| 验证项 | 结果 |
| :--- | :--- |
| `pre-commit validate-config` | exit=0 |
| `pre-commit run --all-files` | **17 项 hook 全部 Passed，exit=0**（4 个上游 rev 全部成功解析并安装） |
| `shellcheck --shell=sh` on `lib/common.sh`、`demo.sh` | **warning 与 info 两级均 0 条告警** |
| `yamllint`（用本仓库自己的严格配置） | exit=0 |
| `ruff check` / `ruff format --check` | 全部通过，格式已合规 |
| `demo.sh` 正常 / 无参数 / 非法参数 / `--help` / `--dry-run` | exit=0 / 2 / 2 / 0 / 0 |
| `demo.ps1`、`demo.bat` 委托链 | exit=0，输出正确 |

实测版本：pre-commit 4.6.2、shellcheck 0.11.0、yamllint 1.38.0、ruff 0.16.10、gitleaks 8.30.1（可选）。

### 验证过程中修掉的两个真 bug

1. **`lib/common.sh` 带了 shebang 却不可执行** —— 它是被 `source` 的库、从不直接执行，不该有 shebang。pre-commit 的 `check-shebang-scripts-are-executable` 准确抓到了这一点，已移除。
2. **`lib/common.ps1` 选中了错误的 shell** —— Windows 上 `Get-Command bash` 很可能命中 `%LOCALAPPDATA%\Microsoft\WindowsApps\bash.exe`，那是 **WSL 存根**，不是 Git Bash。它用 `/mnt/d/` 挂载、还需要装发行版，结果表现为一个看不出原因的 `exit 127: No such file or directory`。现在改为**显式优先 Git for Windows 的 `sh`**，并按 shell 家族（msys → `/d/`、wsl → `/mnt/d/`、posix → 原样）映射路径。

## Windows 注意事项

- **ExecutionPolicy**：跑 `.ps1` 若报"禁止运行脚本"：
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```
  `demo.bat` 已内置 `-ExecutionPolicy Bypass`，不受影响。
- **CRLF 警告是正常的**：`git add` 时提示 `LF will be replaced by CRLF` 说明 `.gitattributes` 正在按设计工作。
- **`sh` 从哪来**：Git for Windows 自带。`lib/common.ps1` 会主动去 `%ProgramFiles%\Git\bin\sh.exe` 等位置找，不依赖 PATH 顺序。

## 故障排除

| 现象 | 原因与处理 |
| :--- | :--- |
| `check-shebang-scripts-are-executable` 失败 | 复制文件时丢了执行位：`git add --chmod=+x '*.sh'`（仅对**要直接执行**的脚本；被 source 的库应删掉 shebang） |
| `exit 127` + `No such file or directory` | 委托链选错了 shell 或路径形式不对。确认 `Get-PosixShell` 返回的是 Git 的 `sh.exe` 且 `Family=msys` |
| `mixed line ending` 报错但不自动修 | 故意为之（`--fix=no`）。`.gitattributes` 已经管换行符，自动改写会跟 CRLF 规则打架 |
| yamllint 要求 `---` 文档头 | 本仓库配置 `document-start: present`，新建 YAML 记得加 |
| `Attempt to write a readonly database` | pre-commit 缓存目录权限问题，多见于沙箱；正常环境不会有 |
| yamllint 报 `truthy value should be one of [false, true]` 且指向 `on:` | YAML 1.1 把裸 `on` 解析成布尔真，而本仓库的 `truthy` 规则**连键名一起查**。写成 `"on":` 即可（`.github/workflows/ci.yml` 就是这么做的，上游模板同款处理） |

## 参考

- 上游模板：<https://github.com/snowdreamtech/template>
- 最有价值的一份规范：该仓库的 `.agent/rules/shell.md`（573 行，建议通读）
- 约定式提交：<https://www.conventionalcommits.org/>
