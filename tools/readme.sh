#!/usr/bin/env bash

# readme.sh
#
# Purpose: Unified entry point for readme workflow (generate, validate, drift check)
#
# Usage:
#   tools/readme.sh sync      — regenerate README from fragments, validate refs
#   tools/readme.sh extract   — reverse: README.md → fragments
#   tools/readme.sh check     — validate refs + drift (read-only, no writes)
#   tools/readme.sh all       — sync + check (full pre-commit)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cmd="${1:-sync}"

case "$cmd" in
  sync)
    echo "=== generate ==="
    bash "$SCRIPT_DIR/generate-readme.sh"
    echo
    echo "=== validate refs ==="
    bash "$SCRIPT_DIR/check-refs.sh"
    ;;

  extract)
    bash "$SCRIPT_DIR/readme-to-fragments.sh"
    ;;

  check)
    echo "=== validate refs ==="
    bash "$SCRIPT_DIR/check-refs.sh"
    echo
    echo "=== drift ==="
    bash "$SCRIPT_DIR/check-readme-drift.sh" || true
    ;;

  all)
    echo "=== generate ==="
    bash "$SCRIPT_DIR/generate-readme.sh"
    echo
    echo "=== validate refs ==="
    bash "$SCRIPT_DIR/check-refs.sh"
    echo
    echo "=== drift ==="
    bash "$SCRIPT_DIR/check-readme-drift.sh" || true
    echo
    echo "all checks passed"
    ;;

  *)
    echo "usage: readme.sh {sync|extract|check|all}" >&2
    exit 1
    ;;
esac
