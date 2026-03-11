# runtime.sh
#
# Purpose: Provide common runtime helpers for shell scripts
#
# This module:
# - Detects CI environment
# - Provides safe execution wrappers
# - Offers confirmation prompts
# - Checks command availability
# - Handles root escalation

# shellcheck shell=bash

is_ci() {
	[[ "${CI:-0}" == "1" ]] || [[ "${CI:-false}" == "true" ]]
}

has_command() {
	command -v "$1" >/dev/null 2>&1
}

require_cmds() {
	local missing=()
	for cmd in "$@"; do
		if ! has_command "$cmd"; then
			missing+=("$cmd")
		fi
	done
	if [[ ${#missing[@]} -gt 0 ]]; then
		log_error "Missing required commands: ${missing[*]}"
		return 1
	fi
}

require_root() {
	if [[ $EUID -ne 0 ]]; then
		if has_command sudo; then
			exec sudo "$0" "$@"
		else
			log_error "This script requires root privileges"
			exit 1
		fi
	fi
}

confirm_action() {
	local prompt="${1:-Continue?}"
	local default="${2:-no}"

	if is_ci; then
		return 0
	fi

	local yn
	case "$default" in
	yes | y)
		read -rp "$prompt [Y/n] " yn </dev/tty
		[[ "$yn" =~ ^[Yy]?$ ]] && return 0
		;;
	no | n | "")
		read -rp "$prompt [y/N] " yn </dev/tty
		[[ "$yn" =~ ^[Yy]$ ]] && return 0
		;;
	esac
	return 1
}

safe_exec() {
	if [[ "${DRY_RUN:-0}" == "1" ]]; then
		log_warn "Dry-run: would execute: $*"
		return 0
	fi

	"$@"
}
