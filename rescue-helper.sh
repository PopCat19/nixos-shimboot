#!/usr/bin/env bash
#
# rescue-helper.sh
#
# Purpose: Thin wrapper for backward compatibility
#
# This module:
# - Delegates to tools/rescue/rescue-helper.sh

set -Eeuo pipefail

exec "$(dirname "${BASH_SOURCE[0]}")/tools/rescue/rescue-helper.sh" "$@"
