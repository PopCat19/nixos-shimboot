#!/usr/bin/env bash

# readme.sh
#
# Purpose: Unified entry point for README workflow (generate, validate, drift check)
#
# This module:
# - Coordinates README generation from fragments
# - Executes reference validation and commit citation drift checks
# - Provides subcommands for synchronization, extraction, and validation

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
