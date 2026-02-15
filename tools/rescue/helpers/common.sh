#!/usr/bin/env bash
# common.sh
#
# Purpose: Provide shared colors, logging, cleanup, traps, and global state.
#
# This module:
# - Defines ANSI color codes for consistent output
# - Provides logging functions (step, info, warn, error, success, section)
# - Manages global state variables (MOUNTPOINT, MOUNTED, TARGET_PARTITION)
# - Registers cleanup trap for safe exit handling

# === ANSI Color Codes ===
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'
ANSI_CYAN='\033[1;36m'
# shellcheck disable=SC2034 # Available for future use
ANSI_MAGENTA='\033[1;35m'

# === Global State ===
# Current menu breadcrumb trail
BREADCRUMB="Main"
# shellcheck disable=SC2034 # Global state used across modules
MOUNTPOINT="${MOUNTPOINT:-/mnt/nixos-rescue}"
# shellcheck disable=SC2034 # Global state used across modules
MOUNTED="${MOUNTED:-0}"
# shellcheck disable=SC2034 # Global state used across modules
TARGET_PARTITION="${TARGET_PARTITION:-}"
# shellcheck disable=SC2034 # Global state used across modules
PROFILE_DIR=""
EDITOR="${EDITOR:-nano}"
HOME_BACKUP_DIR="${HOME_BACKUP_DIR:-/tmp/home-backups}"

# === Path Resolution Helpers ===

# Resolve a symlink inside the mounted filesystem without escaping to host.
# Absolute targets get MOUNTPOINT prepended; relative targets resolve
# against the link's parent directory.
resolve_mounted_link() {
	local link_path="$1"
	local target
	target="$(readlink "$link_path")"

	if [[ "$target" == /* ]]; then
		echo "${MOUNTPOINT}${target}"
	else
		echo "$(dirname "$link_path")/$target"
	fi
}

# Return the raw symlink target (store path without MOUNTPOINT prefix).
# Needed for nix store commands that accept --store.
resolve_store_path() {
	local link_path="$1"
	readlink "$link_path"
}

# === Logging Functions ===

log_step() {
	printf "${ANSI_BOLD}${ANSI_BLUE}[%s] %s${ANSI_CLEAR}\n" "$1" "$2"
}

log_info() {
	printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"
}

log_warn() {
	printf "${ANSI_YELLOW}  ⚠ %s${ANSI_CLEAR}\n" "$1"
}

log_error() {
	printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"
}

log_success() {
	printf "${ANSI_GREEN}  ✓ %s${ANSI_CLEAR}\n" "$1"
}

log_section() {
	printf "\n${ANSI_BOLD}${ANSI_CYAN}─── %s ───${ANSI_CLEAR}\n" "$1"
}

# === Cleanup & Signal Handling ===

cleanup() {
	set +e
	log_info "Rescue cleanup in progress..."

	local mount_points=(
		"/mnt/bootloader-rescue"
		"$MOUNTPOINT/home"
		"$MOUNTPOINT/dev"
		"$MOUNTPOINT/proc"
		"$MOUNTPOINT/sys"
		"$MOUNTPOINT"
	)

	for m in "${mount_points[@]}"; do
		if mountpoint -q "$m" 2>/dev/null; then
			log_info "Unmounting $m"
			umount "$m" 2>/dev/null || umount -l "$m" 2>/dev/null || true
		fi
	done

	sync
	log_info "Cleanup complete."
	set -e
}

handle_interrupt() {
	echo
	log_warn "Keyboard interrupt detected — performing safe cleanup"
	trap - INT TERM EXIT
	cleanup
	log_error "Rescue Helper aborted by user."
	exit 130
}

# Register traps (call once from entry point)
register_traps() {
	trap cleanup EXIT TERM
	trap handle_interrupt INT
}

# === Utility Functions ===

ensure_root() {
	if [[ "$EUID" -ne 0 ]]; then
		log_error "This script must be run as root"
		log_info "Usage: sudo $0 [partition]"
		exit 1
	fi
}

pause() {
	echo
	gum style --faint "Press Enter to continue..."
	read -rsn1 _
}

set_breadcrumb() {
	BREADCRUMB="$*"
}
