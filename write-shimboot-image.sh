#!/usr/bin/env bash
#
# write-shimboot-image.sh
#
# Purpose: Thin wrapper for backward compatibility
#
# This module:
# - Delegates to tools/write/write-shimboot-image.sh

set -Eeuo pipefail

exec "$(dirname "${BASH_SOURCE[0]}")/tools/write/write-shimboot-image.sh" "$@"
