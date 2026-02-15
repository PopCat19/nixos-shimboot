#!/usr/bin/env bash
# rescue.sh
#
# Purpose: Entry point for NixOS Shimboot Rescue Helper with gum TUI.
#
# This script:
# - Validates gum dependency (hard requirement)
# - Detects or accepts target partition
# - Initializes rescue environment
# - Launches main TUI menu

set -Eeuo pipefail

# Get script directory for sourcing helpers (resolve symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
HELPERS_DIR="$SCRIPT_DIR/helpers"

# Source common functions first (provides logging, colors, global state)
source "$HELPERS_DIR/common.sh"

# Check gum dependency (hard requirement)
if ! command -v gum &>/dev/null; then
	log_error "gum is required but not installed"
	log_info "Install with: nix profile install nixpkgs#gum"
	log_info "Or: go install github.com/charmbracelet/gum@latest"
	exit 1
fi

# Source remaining helpers
source "$HELPERS_DIR/detect.sh"
source "$HELPERS_DIR/mount.sh"
source "$HELPERS_DIR/generations.sh"
source "$HELPERS_DIR/filesystem.sh"
source "$HELPERS_DIR/home.sh"
source "$HELPERS_DIR/bootstrap.sh"
source "$HELPERS_DIR/activate.sh"
source "$HELPERS_DIR/tui.sh"

main() {
	ensure_root

	# Check if running in Nix devshell and show recommendation
	if [[ -z "${IN_NIX_SHELL:-}" ]]; then
		log_warn "Not running in a Nix devshell"
		log_info "For best experience, run: nix develop"
		log_info "This ensures all dependencies are available"
		echo
	fi

	# Handle command line argument for partition
	if [[ -n "${1:-}" ]]; then
		if [[ "$1" == "auto" ]]; then
			if ! detect_partition; then
				exit 1
			fi
		else
			TARGET_PARTITION="$1"
		fi
	else
		# No argument - try auto-detect or prompt
		if ! detect_partition; then
			log_info "Auto-detection failed. Select partition manually."
			if ! select_partition_manually; then
				exit 1
			fi
		fi
	fi

	# Validate partition exists
	if [[ ! -b "$TARGET_PARTITION" ]]; then
		log_error "Partition does not exist: $TARGET_PARTITION"
		list_available_partitions
		exit 1
	fi

	# Check and handle existing mounts
	if check_partition_mounted "$TARGET_PARTITION"; then
		if ! unmount_partition "$TARGET_PARTITION"; then
			exit 1
		fi
	fi

	log_info "Target partition: $TARGET_PARTITION"
	echo
	log_section "Rescue Environment Ready"
	log_info "Use menu prompts below for recovery operations"
	log_info "Press Ctrl+C anytime for safe cleanup"
	echo

	# Register cleanup traps
	register_traps

	# Mount system initially (read-only)
	mount_system "ro"

	# Enter main menu
	main_menu
}

main "$@"
