# ---------------------------------------------------------------------------
# lib/common.sh - shared helpers for POSIX shell automation scripts.
#
# This file is SOURCED, never executed, so it deliberately carries NO shebang
# and is NOT marked executable. pre-commit's check-shebang-scripts-are-executable
# hook enforces exactly that distinction: a shebang is a promise that the file
# can be run directly.
#
# WHY THIS FILE EXISTS
#   snowdreamtech/template's .agent/rules/shell.md makes it MANDATORY for every
#   script to source "lib/common.sh" and call guard_project_root() and
#   parse_common_args(). But scripts/lib/ was never shipped in that repository -
#   the rules point at a library that does not exist. This is a working,
#   ShellCheck-clean implementation of that contract.
#
# USAGE
#   SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
#   . "$SCRIPT_DIR/lib/common.sh"
#
#   main() {
#       guard_project_root
#       ...
#   }
#   main "$@"
# ---------------------------------------------------------------------------

# Guard against double-sourcing. This file must be SOURCED, not executed.
if [ "${_COMMON_SH_LOADED:-0}" = "1" ]; then
    return 0
fi
_COMMON_SH_LOADED=1

# ---------------------------------------------------------------------------
# Colour support
#   Enabled only when stdout is a terminal and NO_COLOR is unset, so piped and
#   redirected output stays free of escape sequences.
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    _C_RESET=$(printf '\033[0m')
    _C_INFO=$(printf '\033[1;34m')
    _C_OK=$(printf '\033[1;32m')
    _C_WARN=$(printf '\033[1;33m')
    _C_ERR=$(printf '\033[1;31m')
else
    _C_RESET=''
    _C_INFO=''
    _C_OK=''
    _C_WARN=''
    _C_ERR=''
fi

# ---------------------------------------------------------------------------
# Logging
#   Informational output goes to stdout; warnings and errors go to stderr.
#   printf (not echo) is used throughout: echo's handling of -n, -e and
#   backslashes varies between implementations.
# ---------------------------------------------------------------------------
log_info() {
    printf '%s[INFO]%s %s\n' "$_C_INFO" "$_C_RESET" "$*"
}

log_success() {
    printf '%s[ OK ]%s %s\n' "$_C_OK" "$_C_RESET" "$*"
}

log_warn() {
    printf '%s[WARN]%s %s\n' "$_C_WARN" "$_C_RESET" "$*" >&2
}

log_error() {
    printf '%s[FAIL]%s %s\n' "$_C_ERR" "$_C_RESET" "$*" >&2
}

# Debug output is opt-in via -v/--verbose. It always goes to stderr so that it
# can never corrupt command substitution (`x=$(some_fn)`).
log_debug() {
    [ "${VERBOSE:-0}" = "1" ] || return 0
    printf '[DEBG] %s\n' "$*" >&2
}

# Print an error and terminate with a non-zero status.
die() {
    log_error "$*"
    exit 1
}

# ---------------------------------------------------------------------------
# Command availability
#   `command -v` is the portable check. `which` is a separate binary whose
#   presence, exit codes and output differ across platforms.
# ---------------------------------------------------------------------------
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

require_cmd() {
    local _cmd
    for _cmd in "$@"; do
        if ! has_cmd "$_cmd"; then
            die "required command not found: $_cmd"
        fi
    done
}

# ---------------------------------------------------------------------------
# Environment detection
# ---------------------------------------------------------------------------
is_ci_env() {
    [ "${CI:-}" = "true" ] || [ "${GITHUB_ACTIONS:-}" = "true" ]
}

# ---------------------------------------------------------------------------
# Temporary workspace
#   Created lazily on first use and removed automatically on exit, including
#   on interruption, so a failed run never leaves debris behind.
# ---------------------------------------------------------------------------
_TMP_DIR=''

make_tmpdir() {
    if [ -z "$_TMP_DIR" ]; then
        _TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/autoscript.XXXXXX") \
            || die 'failed to create a temporary directory'
        log_debug "created temporary directory: $_TMP_DIR"
    fi
    printf '%s\n' "$_TMP_DIR"
}

_common_cleanup() {
    if [ -n "$_TMP_DIR" ] && [ -d "$_TMP_DIR" ]; then
        rm -rf "$_TMP_DIR"
        log_debug "removed temporary directory: $_TMP_DIR"
        _TMP_DIR=''
    fi
}

# Cleanup runs on normal exit and on Ctrl+C / termination (128 + signal).
trap _common_cleanup EXIT
trap '_common_cleanup; exit 130' INT TERM

# ---------------------------------------------------------------------------
# Dry-run aware command execution
#   Wrap anything with side effects:
#       run rm -rf "$stale_dir"
#   With --dry-run the command is printed instead of executed.
# ---------------------------------------------------------------------------
run() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        log_info "dry-run: $*"
        return 0
    fi
    if [ "${VERBOSE:-0}" = "1" ]; then
        printf '[EXEC] %s\n' "$*" >&2
    fi
    "$@"
}

# ---------------------------------------------------------------------------
# Project root guard
#   Prevents a destructive script from operating on the wrong directory because
#   it was invoked from somewhere unexpected.
#   Override the marker with PROJECT_ROOT_MARKER=package.json if needed.
# ---------------------------------------------------------------------------
guard_project_root() {
    local _marker="${PROJECT_ROOT_MARKER:-.git}"
    if [ ! -e "$_marker" ]; then
        die "must be run from the project root (missing: $_marker)"
    fi
}

# ---------------------------------------------------------------------------
# Composable common-argument parsing
#
#   POSIX sh has no arrays, so a helper physically cannot hand an arbitrary
#   argv back to its caller. Instead, this consumes ONE argument and reports
#   whether it did, leaving the caller in charge of its own loop:
#
#       while [ $# -gt 0 ]; do
#           if parse_common_arg "$1"; then shift; continue; fi
#           case "$1" in
#               --) shift; break ;;
#               -*) log_error "unknown option: $1"; usage >&2; exit 2 ;;
#               *)  break ;;
#           esac
#       done
#
#   Recognised: -v/--verbose, -n/--dry-run, -h/--help
#   -h calls your usage() function when one is defined, then exits 0.
# ---------------------------------------------------------------------------
parse_common_arg() {
    case "${1:-}" in
        -v|--verbose)
            VERBOSE=1
            return 0
            ;;
        -n|--dry-run)
            DRY_RUN=1
            return 0
            ;;
        -h|--help)
            if has_cmd usage; then
                usage
            else
                printf 'Usage: %s [-n|--dry-run] [-v|--verbose] [-h|--help]\n' \
                    "${PROG_NAME:-$0}"
            fi
            exit 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Next Actions prompt
#   Printed once by the top-level script to tell the user what to do next.
# ---------------------------------------------------------------------------
print_next_actions() {
    [ "$#" -gt 0 ] || return 0
    local _action
    printf '\nNext actions:\n'
    for _action in "$@"; do
        printf '  - %s\n' "$_action"
    done
}
