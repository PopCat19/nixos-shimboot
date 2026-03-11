#!/usr/bin/env bash
#
# inspect-image.sh
#
# Purpose: Thin wrapper for backward compatibility
#
# This module:
# - Delegates to tools/inspect/inspect-image.sh

set -Eeuo pipefail

exec "$(dirname "${BASH_SOURCE[0]}")/tools/inspect/inspect-image.sh" "$@"
