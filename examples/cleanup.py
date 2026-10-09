"""Delete files older than a given number of days.

A reference implementation showing the Python conventions this repository's
linter configuration enforces:

* argparse for CLI parsing, with ``--dry-run`` as a first-class option
* pathlib instead of os.path string juggling
* a ``main()`` entry point guarded by ``if __name__ == "__main__":``
* explicit exit codes (0 = success, non-zero = failure)

Run with:
    python examples/cleanup.py --dir ./logs --days 30 [--dry-run]
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

SECONDS_PER_DAY = 86_400


def find_stale_files(directory: Path, days: int) -> list[Path]:
    """Return regular files under *directory* older than *days* days."""
    cutoff = time.time() - (days * SECONDS_PER_DAY)
    stale: list[Path] = []
    for path in sorted(directory.rglob("*")):
        if path.is_file() and path.stat().st_mtime < cutoff:
            stale.append(path)
    return stale


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dir", type=Path, required=True, help="directory to scan")
    parser.add_argument("--days", type=int, default=30, help="age threshold in days")
    parser.add_argument("--dry-run", action="store_true", help="list matches without deleting")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if not args.dir.is_dir():
        print(f"error: not a directory: {args.dir}", file=sys.stderr)
        return 1

    if args.days < 0:
        print("error: --days must not be negative", file=sys.stderr)
        return 2

    stale = find_stale_files(args.dir, args.days)
    if not stale:
        print(f"nothing to do: no files older than {args.days} days in {args.dir}")
        return 0

    for path in stale:
        if args.dry_run:
            print(f"dry-run: would delete {path}")
        else:
            path.unlink()
            print(f"deleted {path}")

    verb = "would delete" if args.dry_run else "deleted"
    print(f"{verb} {len(stale)} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
