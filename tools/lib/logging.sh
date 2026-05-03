# logging.sh
#
# Purpose: Provide unified logging functions and shared ANSI color variables
#
# This module:
# - Defines ANSI color codes with CI-safe fallback
# - Exports colors for use by other scripts
# - Provides log_step, log_info, log_warn, log_error, log_success, log_section

# shellcheck shell=bash

if [[ -t 1 && -z "${NO_COLOR:-}" && -z "${CI:-}" && -z "${GITHUB_ACTIONS:-}" ]]; then
	COLOR_BOLD='\033[1m'
	COLOR_DIM='\033[2m'
	COLOR_GREEN='\033[1;32m'
	COLOR_BLUE='\033[1;34m'
	COLOR_YELLOW='\033[1;33m'
	COLOR_RED='\033[1;31m'
	COLOR_CYAN='\033[1;36m'
	COLOR_MAGENTA='\033[1;35m'
	COLOR_CLEAR='\033[0m'
else
	COLOR_BOLD=''
	COLOR_DIM=''
	COLOR_GREEN=''
	COLOR_BLUE=''
	COLOR_YELLOW=''
	COLOR_RED=''
	COLOR_CYAN=''
	COLOR_MAGENTA=''
	COLOR_CLEAR=''
fi

# Legacy aliases for backward compat with scripts using ANSI_ prefix
export ANSI_CLEAR="$COLOR_CLEAR" ANSI_BOLD="$COLOR_BOLD"
export ANSI_GREEN="$COLOR_GREEN" ANSI_BLUE="$COLOR_BLUE"
export ANSI_YELLOW="$COLOR_YELLOW" ANSI_RED="$COLOR_RED"
export ANSI_CYAN="$COLOR_CYAN" ANSI_MAGENTA="$COLOR_MAGENTA"
# Canonical names
export COLOR_BOLD COLOR_DIM COLOR_GREEN COLOR_BLUE COLOR_YELLOW
export COLOR_RED COLOR_CYAN COLOR_MAGENTA COLOR_CLEAR

log_step() {
	printf "${ANSI_BOLD}${ANSI_BLUE}[%s] %s${ANSI_CLEAR}\n" "$1" "$2"
}

log_info() {
	printf "${ANSI_GREEN}  > %s${ANSI_CLEAR}\n" "$1"
}

log_warn() {
	printf "${ANSI_YELLOW}  ! %s${ANSI_CLEAR}\n" "$1"
}

log_error() {
	printf "${ANSI_RED}  x %s${ANSI_CLEAR}\n" "$1"
}

log_success() {
	printf "${ANSI_GREEN}  + %s${ANSI_CLEAR}\n" "$1"
}

log_section() {
	printf "\n${ANSI_BOLD}${ANSI_CYAN}=== %s ===${ANSI_CLEAR}\n\n" "$1"
}
