# automation-starter

[![CI](https://github.com/chri321/automation-starter/actions/workflows/ci.yml/badge.svg)](https://github.com/chri321/automation-starter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://pre-commit.com)
[![Platforms](https://img.shields.io/badge/platforms-Linux%20%7C%20macOS%20%7C%20Windows-blue)](#前置条件)
[![Python](https://img.shields.io/badge/python-3.9%2B-blue?logo=python)](https://www.python.org)

[English](README.md) | [简体中文](README_zh-CN.md)

面向**自动化脚本仓库**的轻量跨平台工程化骨架——就是那种主体是 Shell、
PowerShell、Python 胶水脚本、而非一个应用程序的仓库。直接克隆，或只挑你要的
那几个文件，就能用一次 `pre-commit` 安装换来 lint、格式化、换行符归一化和密钥扫描。

不需要引入工具链编排器，也不需要下载一堆多语言运行时矩阵。全局只装 `pre-commit`
一个东西。

## 目录

- [特性](#特性)
- [前置条件](#前置条件)
- [安装](#安装)
- [快速开始](#快速开始)
- [使用方法](#使用方法)
  - [Shell 脚本](#shell-脚本)
  - [`lib/common.sh` API](#libcommonsh-api)
  - [Python 脚本](#python-脚本)
  - [跨平台包装器](#跨平台包装器)
- [项目结构](#项目结构)
- [配置](#配置)
  - [已启用的 hook](#已启用的-hook)
  - [可选 hook](#可选-hook)
- [持续集成](#持续集成)
- [验证记录](#验证记录)
- [故障排除](#故障排除)
- [贡献](#贡献)
- [许可证](#许可证)
- [致谢](#致谢)

## 特性

- **只有一个依赖。** 所有 hook 都指向标准上游仓库，由 `pre-commit` 装进它自己
  隔离的虚拟环境，此外无需安装任何东西。
- **ShellCheck 零告警的 POSIX Shell 库。** `lib/common.sh` 提供日志、参数解析、
  支持 dry-run 的命令执行、项目根目录守卫，以及临时目录自动清理。
- **真正可用的跨平台桥接。** `task.bat` → `task.ps1` → `task.sh` 委托链，逻辑只
  写在 `.sh` 里。已处理两个会让这类桥接**静默失效**的 Windows 陷阱（见[致谢](#致谢)）。
- **按平台锁定换行符。** `.gitattributes` 强制 `*.sh` 用 LF、`*.ps1`/`*.bat` 用
  CRLF，脚本不会在 Linux 上因 `sh\r` 报错。
- **密钥扫描就绪。** 预留了 `gitleaks` hook——硬编码 token 是自动化脚本最经典的错误。
- **版本号全部核实。** 每个 hook 的 `rev` 都是对着 GitHub API 确认过的真实发布标签，
  没有任何猜测。

## 前置条件

| 依赖 | 版本 | 说明 |
| :--- | :--- | :--- |
| Python | 3.9+ | `pre-commit` 及其 Python hook 环境 |
| Git | 较新版本即可 | 本骨架以 git 钩子形式安装 |
| POSIX shell | 任意 | Git for Windows 自带 `sh`；Linux/macOS 无需额外安装 |
| PowerShell | 5.1+ | 仅可选的 `.ps1` 包装层需要 |

可选工具（只有启用对应 hook 时才需要）：`shfmt`、`PSScriptAnalyzer`（PowerShell
模块）、`gitleaks`。

## 安装

```bash
git clone https://github.com/chri321/automation-starter.git
cd automation-starter
pip install pre-commit
pre-commit install
```

如果要在**已有仓库**里采用，挑需要的文件复制即可，不必克隆：

```bash
# 最小可用集合
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.pre-commit-config.yaml
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.shellcheckrc
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.editorconfig
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.gitattributes
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/.yamllint.yml
curl -O https://raw.githubusercontent.com/chri321/automation-starter/main/ruff.toml
pre-commit install
```

## 快速开始

```bash
pip install pre-commit          # 1. 安装唯一的全局依赖
pre-commit install              # 2. 在本仓库激活 git 钩子
pre-commit run --all-files      # 3. 立即全量检查
```

安装就这三步。此后每次 `git commit` 都会自动触发检查。

## 使用方法

### Shell 脚本

每个脚本都从这个骨架开始：

```sh
set -eu                                    # 注意：不用 pipefail，POSIX sh 不支持

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/common.sh"              # 相对层级按实际情况调整

PROG_NAME=$(basename "$0")

usage() {
    cat <<EOF
Usage: $PROG_NAME [OPTIONS] <args>
EOF
}

main() {
    # 公共参数交给库消费，自己的参数在自己的 case 里处理
    while [ $# -gt 0 ]; do
        if parse_common_arg "$1"; then shift; continue; fi
        case "$1" in
            --) shift; break ;;
            -*) log_error "unknown option: $1"; usage >&2; exit 2 ;;
            *)  break ;;
        esac
    done

    guard_project_root                     # 拒绝在错误的目录下执行
    work_dir=$(make_tmpdir)                # 惰性创建，退出时自动清理
    run rm -rf "$stale_dir"                # --dry-run 下只打印、不执行
    log_success 'done'
    print_next_actions 'Run: pre-commit run --all-files'
}

main "$@"
```

### `lib/common.sh` API

| 函数 | 说明 |
| :--- | :--- |
| `log_info` / `log_success` / `log_warn` / `log_error` | 分级日志。stdout 非 TTY 或设置了 `NO_COLOR` 时自动去色；警告与错误走 stderr。 |
| `log_debug` | 仅在 `-v` 下输出，且**始终写 stderr**，不会污染 `$(...)`。 |
| `die "message"` | 报错并以非零码退出。 |
| `has_cmd` / `require_cmd` | 用 `command -v` 探测命令，绝不用 `which`。 |
| `is_ci_env` | 设置了 `CI` 或 `GITHUB_ACTIONS` 时为真。 |
| `make_tmpdir` | 惰性创建临时目录，并在 `EXIT`、`INT`、`TERM` 时自动清理。 |
| `run <cmd...>` | 执行命令，并尊重 `--dry-run` 与 `--verbose`。 |
| `guard_project_root` | 校验根目录标记（默认 `.git`，可用 `PROJECT_ROOT_MARKER` 覆盖）。 |
| `parse_common_arg "$1"` | 识别 `-v`、`-n`、`-h`。**返回 0 表示已消费该参数。** |
| `print_next_actions '...'` | 打印标准收尾提示。 |

> **为什么是 `parse_common_arg` 而不是 `parse_common_args "$@"`？**
> POSIX Shell 没有数组，辅助函数在物理上无法把任意 `argv` 交还给调用方。这里的做法是
> 返回"是否已消费当前参数"，由调用方保留自己的循环。这是 POSIX sh 下**正确的设计**，
> 不是偷懒。

### Python 脚本

`examples/cleanup.py` 是参考实现：`argparse` 且把 `--dry-run` 作为一等选项、用
`pathlib` 而非 `os.path` 拼字符串、`main()` 由 `if __name__ == "__main__":` 守护、
显式退出码。

```bash
python examples/cleanup.py --dir ./logs --days 30 --dry-run
ruff check examples/cleanup.py
```

### 跨平台包装器

需要同时在 Windows 上运行的脚本，使用三文件委托链。**逻辑全部写在 `.sh` 里**，
包装器只做转发。

```text
task.bat   ->   task.ps1   ->   task.sh
（CMD 入口）    （PS 入口）      （POSIX 逻辑，唯一事实来源）
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

`Invoke-ShellDelegation` 会定位 POSIX shell、把脚本路径转换成该 shell 期望的形式、
转发参数并传递退出码。

## 项目结构

```text
automation-starter/
├── .github/
│   └── workflows/
│       └── ci.yml                 # 三平台 pre-commit 矩阵
├── examples/
│   ├── cleanup.py                 # Python 参考实现
│   ├── demo.sh                    # Shell 参考实现
│   ├── demo.ps1                   # 瘦 PowerShell 包装器
│   └── demo.bat                   # 瘦 CMD 包装器
├── lib/
│   ├── common.sh                  # POSIX Shell 共享库
│   └── common.ps1                 # PowerShell 委托辅助库
├── .editorconfig                  # 缩进 / 换行 / 编码规范
├── .gitattributes                 # 按平台锁定换行符
├── .gitignore
├── .pre-commit-config.yaml        # hook 集合
├── .shellcheckrc                  # ShellCheck 配置
├── .yamllint.yml                  # YAML 规则
├── PSScriptAnalyzerSettings.psd1  # PowerShell 分析设置
├── ruff.toml                      # Python lint 规则
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE                        # MIT，保持原文以便检测工具正确识别
├── NOTICE                         # 派生配置层的署名
├── README.md                      # 英文规范版（主版本）
└── README_zh-CN.md                # 本文件
```

## 配置

### 已启用的 hook

| Hook | 作用 |
| :--- | :--- |
| `trailing-whitespace`、`end-of-file-fixer`、`mixed-line-ending` | 文件卫生。`mixed-line-ending` 只报告不重写，因为换行符归 `.gitattributes` 管。 |
| `fix-byte-order-marker` | 去除 UTF-8 BOM，与 `.editorconfig` 一致。 |
| `check-merge-conflict`、`check-case-conflict` | 抓残留冲突标记与大小写冲突的文件名。 |
| `check-symlinks`、`destroyed-symlinks` | 检测失效与被覆盖的符号链接。 |
| `check-added-large-files` | 拦截超过 1 MB 的误提交二进制文件。 |
| `check-executables-have-shebangs`、`check-shebang-scripts-are-executable` | 双向维护 shebang 与可执行位的契约。 |
| `detect-private-key` | 拦截私钥提交。 |
| `shellcheck`（POSIX 与 Bash 两个变体） | Shell 静态分析。 |
| `yamllint` | 按 [`.yamllint.yml`](.yamllint.yml) 校验 YAML。 |
| `ruff`、`ruff-format` | Python lint 与格式化。 |

### 可选 hook

默认关闭，因为每个都需要你本机有对应二进制或模块。装好工具后，在
[`.pre-commit-config.yaml`](.pre-commit-config.yaml) 中取消对应段落的注释即可。

```bash
# shfmt - Shell 格式化
go install mvdan.cc/sh/v3/cmd/shfmt@latest

# PSScriptAnalyzer - PowerShell 静态分析
pwsh -Command 'Install-Module -Name PSScriptAnalyzer -Scope CurrentUser'

# gitleaks - 提交时扫描密钥
winget install gitleaks        # Windows
brew install gitleaks          # macOS
```

## 持续集成

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) 在 `ubuntu-latest`、
`windows-latest`、`macos-latest` 上运行同一套 hook，并使用 `fail-fast: false`，
让平台特有的回归暴露出来而不是被掩盖。三平台并行正是重点：换行符与 shell 选择的
问题只在其中部分平台上出现。

## 验证记录

这套骨架是测出来的，不是想出来的。证据：

| 检查项 | 结果 |
| :--- | :--- |
| `pre-commit validate-config` | exit 0 |
| `pre-commit run --all-files` | 17 项 hook 全部通过，exit 0 |
| `shellcheck --shell=sh` 跑 `lib/common.sh` 与 `demo.sh` | `warning` 与 `info` 两级均 0 条告警 |
| `yamllint`（用本仓库自己的严格配置） | exit 0 |
| `ruff check` 与 `ruff format --check` | 通过，格式已合规 |
| `demo.sh` 正常 / 无参数 / 非法参数 / `--help` / `--dry-run` | exit 0 / 2 / 2 / 0 / 0 |
| `demo.ps1` 与 `demo.bat` 委托链 | exit 0，输出正确 |

实测版本：pre-commit 4.6.2、ShellCheck 0.11.0、yamllint 1.38.0、ruff 0.16.10、
gitleaks 8.30.1。

这个过程抓出并修掉了两个真实缺陷，均已记录在 [CHANGELOG](CHANGELOG.md)。

## 故障排除

| 现象 | 原因与处理 |
| :--- | :--- |
| `check-shebang-scripts-are-executable` 失败 | 复制文件时丢了执行位：`git add --chmod=+x '*.sh'`。仅适用于**要直接执行**的脚本——被 `source` 的库必须完全没有 shebang。 |
| 文件明明存在却报 `exit 127` + `No such file or directory` | 委托辅助库选错了 shell 或路径形式。Windows 上 `Get-Command bash` 常命中 `%LOCALAPPDATA%\Microsoft\WindowsApps` 里的 WSL 存根，它把磁盘挂在 `/mnt/d`。`Get-PosixShell` 已处理此问题；请确认它返回的是 Git 的 `sh.exe` 且 `Family=msys`。 |
| `mixed line ending` 报错却不自动修 | 故意为之（`--fix=no`）。换行符归 `.gitattributes` 管，让 hook 重写文件会与它自己执行的 CRLF 规则打架。 |
| yamllint 报 `truthy value should be one of [false, true]` 且指向 `on:` | YAML 1.1 把裸 `on` 解析为布尔真，而本仓库的严格 `truthy` 规则**连键名一起检查**。给键加引号即可：`"on":`。GitHub Actions 两种写法都接受。 |
| yamllint 要求 `---` 文档头 | 本仓库启用了 `document-start: present`，新建 YAML 记得加 `---`。 |
| `Attempt to write a readonly database` | `pre-commit` 缓存目录权限问题，多见于沙箱环境；正常环境不会出现。 |
| `git` 连不上 github.com | 在 github.com 被 SNI 阻断的网络下，让 git 走本地代理，并只作用于 GitHub：`git config --global http.https://github.com.proxy http://127.0.0.1:7890` |

## 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。简述：使用约定式提交信息；hook 必须通过；
任何脚本改动都要保持 `shellcheck --shell=sh` 在 `--severity=info` 下零告警。

## 许可证

[MIT](LICENSE) © 2026 chri321。

## 致谢

配置层（`.editorconfig`、`.gitattributes`、`.shellcheckrc`、`.yamllint.yml`、
`PSScriptAnalyzerSettings.psd1`、`ruff.toml` 及 hook 集合）改编自
[snowdreamtech/template](https://github.com/snowdreamtech/template)，同样是 MIT
许可。署名记录在 [`NOTICE`](NOTICE) 中；[`LICENSE`](LICENSE) 保持 MIT 原文不改动，
以便许可证检测工具正确识别。该项目的 `.agent/rules/shell.md` 是一份极好的 Shell
实战规范，值得通读。

本骨架有两处做法不同，都是测试中踩出来的：

1. **上游隐含地禁止共享库带 shebang。** 它的
   `check-shebang-scripts-are-executable` hook 对被 `source` 的文件带 shebang 报错
   是正确的；本骨架把这一点写明了。
2. **在 Windows 上盲目回退到 `bash` 是个陷阱。** Microsoft Store 的执行别名是
   WSL 存根，不是 Git Bash，失败时只给一个看不出原因的 exit 127。
