# logging.sh
#
# Purpose: Provide unified logging functions with ANSI colors
#
# This module:
# - Defines ANSI color codes
# - Provides log_step, log_info, log_warn, log_error, log_success
# - Auto-detects terminal support for colors

# shellcheck shell=bash

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
	ANSI_CLEAR='\033[0m'
	ANSI_BOLD='\033[1m'
	ANSI_GREEN='\033[1;32m'
	ANSI_BLUE='\033[1;34m'
	ANSI_YELLOW='\033[1;33m'
	ANSI_RED='\033[1;31m'
	ANSI_CYAN='\033[1;36m'
else
	ANSI_CLEAR=''
	ANSI_BOLD=''
	ANSI_GREEN=''
	ANSI_BLUE=''
	ANSI_YELLOW=''
	ANSI_RED=''
	ANSI_CYAN=''
fi

log_step() {
	printf "${ANSI_BOLD}${ANSI_BLUE}[%s] %s${ANSI_CLEAR}\n" "$1" "$2"
}

log_info() {
	printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"
}

log_warn() {
	printf "${ANSI_YELLOW}  ! %s${ANSI_CLEAR}\n" "$1"
}

log_error() {
	printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"
}

log_success() {
	printf "${ANSI_GREEN}  ✓ %s${ANSI_CLEAR}\n" "$1"
}

log_section() {
	printf "\n${ANSI_BOLD}${ANSI_CYAN}=== %s ===${ANSI_CLEAR}\n\n" "$1"
}
