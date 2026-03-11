# args.sh
#
# Purpose: Provide argument parsing utilities
#
# This module:
# - Parses common CLI flags
# - Provides usage/help output

# shellcheck shell=bash

parse_args() {
	local -n _out="$1"
	shift

	_out=()
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			return 2
			;;
		--dry-run)
			export DRY_RUN=1
			;;
		--verbose | -v)
			export VERBOSE=1
			;;
		*)
			_out+=("$1")
			;;
		esac
		shift
	done
}

require_arg() {
	if [[ -z "${2:-}" ]]; then
		log_error "Missing argument for $1"
		return 1
	fi
}

show_usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --dry-run    Show actions without executing
  --verbose    Enable verbose output
  --help       Show this help message
EOF
}
