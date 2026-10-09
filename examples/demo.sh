#!/usr/bin/env sh
# ---------------------------------------------------------------------------
# demo.sh - reference implementation for this starter kit.
#
# Demonstrates the recommended skeleton:
#   * `set -eu` strict mode (not `set -euo pipefail` - pipefail is not POSIX)
#   * sourcing the shared library
#   * composable argument parsing
#   * a main() entry point with a usage() function
#   * dry-run support, temporary directory cleanup, exit codes
#
# Usage:
#   ./examples/demo.sh [-n|--dry-run] [-v|--verbose] [-h|--help] <name>...
# ---------------------------------------------------------------------------

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

PROG_NAME=$(basename "$0")

usage() {
    cat <<EOF
Usage: $PROG_NAME [OPTIONS] <name>...

Greets each name and reports the environment this is running in.

Options:
  -n, --dry-run   Print what would happen without doing it
  -v, --verbose   Enable debug output
  -h, --help      Show this help and exit

Examples:
  $PROG_NAME world
  $PROG_NAME --dry-run alice bob
EOF
}

main() {
    # --- 1. Parse arguments -------------------------------------------------
    while [ $# -gt 0 ]; do
        if parse_common_arg "$1"; then
            shift
            continue
        fi

        case "$1" in
            --)
                shift
                break
                ;;
            -*)
                log_error "unknown option: $1"
                usage >&2
                exit 2
                ;;
            *)
                break
                ;;
        esac
    done

    if [ $# -eq 0 ]; then
        log_error 'at least one <name> is required'
        usage >&2
        exit 2
    fi

    # --- 2. Do the work -----------------------------------------------------
    guard_project_root

    work_dir=$(make_tmpdir)
    log_debug "working directory: $work_dir"

    for name in "$@"; do
        run printf 'Hello, %s!\n' "$name"
    done

    if is_ci_env; then
        log_info 'running in CI'
    else
        log_info 'running locally'
    fi

    log_success 'finished'

    # --- 3. Tell the user what to do next -----------------------------------
    print_next_actions \
        'Run: pre-commit run --all-files' \
        'Refresh hook versions: pre-commit autoupdate'
}

main "$@"
