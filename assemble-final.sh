#!/usr/bin/env bash
#
# assemble-final.sh
#
# Purpose: Thin wrapper for backward compatibility
#
# This module:
# - Delegates to tools/build/assemble-final.sh

set -Eeuo pipefail

exec "$(dirname "${BASH_SOURCE[0]}")/tools/build/assemble-final.sh" "$@"
