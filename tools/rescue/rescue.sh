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

# Script version
readonly SCRIPT_VERSION="1.0.0"

# Get script directory for sourcing helpers (resolve symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
HELPERS_DIR="$SCRIPT_DIR/helpers"

# Display usage information
show_usage() {
	cat <<EOF
NixOS Shimboot Rescue Helper v${SCRIPT_VERSION}

Usage: $(basename "$0") [OPTIONS] [PARTITION|auto]

Arguments:
  PARTITION    Target partition (e.g., /dev/sda1, /dev/nvme0n1p3)
  auto         Auto-detect shimboot partition

Options:
  -h, --help     Show this help message
  -v, --version  Show version information

Examples:
  $(basename "$0")              # Interactive mode with auto-detect fallback
  $(basename "$0") auto         # Auto-detect only
  $(basename "$0") /dev/sda3    # Use specific partition

Dependencies:
  gum           Required for TUI (nix profile install nixpkgs#gum)
  lsblk         For partition detection
  zstd, pv      For home directory backup/restore
  nix           For generation management and garbage collection
EOF
}

# Parse command line arguments
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			show_usage
			exit 0
			;;
		-v | --version)
			echo "NixOS Shimboot Rescue Helper v${SCRIPT_VERSION}"
			exit 0
			;;
		*)
			# Positional argument (partition or "auto")
			if [[ -z "${POSITIONAL_ARG:-}" ]]; then
				POSITIONAL_ARG="$1"
			else
				log_error "Unknown argument: $1"
				show_usage
				exit 1
			fi
			;;
		esac
		shift
	done
}

# Check required dependencies
check_dependencies() {
	local missing=()
	local optional_missing=()

	# Hard requirements
	if ! command -v gum &>/dev/null; then
		missing+=("gum")
	fi

	if ! command -v lsblk &>/dev/null; then
		missing+=("lsblk")
	fi

	# Optional but recommended
	if ! command -v zstd &>/dev/null; then
		optional_missing+=("zstd (required for home backup/restore)")
	fi

	if ! command -v pv &>/dev/null; then
		optional_missing+=("pv (required for progress bars in home backup/restore)")
	fi

	if ! command -v nix &>/dev/null; then
		optional_missing+=("nix (required for generation management)")
	fi

	# Report missing hard dependencies
	if [[ ${#missing[@]} -gt 0 ]]; then
		log_error "Missing required dependencies: ${missing[*]}"
		log_info "Install with: nix profile install nixpkgs#gum nixpkgs#util-linux"
		exit 1
	fi

	# Warn about optional dependencies
	if [[ ${#optional_missing[@]} -gt 0 ]]; then
		log_warn "Optional dependencies not found:"
		for dep in "${optional_missing[@]}"; do
			log_warn "  - $dep"
		done
		echo
	fi
}

# Source helper files with error handling
source_helpers() {
	# Verify helpers directory exists
	if [[ ! -d "$HELPERS_DIR" ]]; then
		echo "Error: Helpers directory not found: $HELPERS_DIR" >&2
		exit 1
	fi

	# Source common functions first (provides logging, colors, global state)
	local common_sh="$HELPERS_DIR/common.sh"
	if [[ ! -f "$common_sh" ]]; then
		echo "Error: Common helper not found: $common_sh" >&2
		exit 1
	fi
	# shellcheck source=helpers/common.sh
	source "$common_sh"

	# Source remaining helpers
	local helpers=("detect.sh" "mount.sh" "generations.sh" "filesystem.sh" "home.sh" "bootstrap.sh" "activate.sh" "tui.sh")
	for helper in "${helpers[@]}"; do
		local helper_path="$HELPERS_DIR/$helper"
		if [[ ! -f "$helper_path" ]]; then
			log_error "Helper not found: $helper_path"
			exit 1
		fi
		# shellcheck source=helpers/$helper
		source "$helper_path"
	done
}

# Validate the target partition
validate_target_partition() {
	# Check partition exists
	if [[ ! -b "$TARGET_PARTITION" ]]; then
		log_error "Partition does not exist: $TARGET_PARTITION"
		list_available_partitions
		exit 1
	fi

	# Check if partition is valid block device
	if [[ ! -e "$TARGET_PARTITION" ]]; then
		log_error "Invalid partition path: $TARGET_PARTITION"
		exit 1
	fi
}

main() {
	# Parse command line arguments
	local POSITIONAL_ARG=""
	parse_args "$@"

	# Check dependencies first (before sourcing helpers)
	check_dependencies

	# Source helpers (provides logging functions)
	source_helpers

	# Now we have logging functions, show startup message
	log_step "Init" "Starting NixOS Shimboot Rescue Helper v${SCRIPT_VERSION}"

	# Ensure running as root
	ensure_root

	# Handle command line argument for partition
	if [[ -n "$POSITIONAL_ARG" ]]; then
		if [[ "$POSITIONAL_ARG" == "auto" ]]; then
			if ! detect_partition; then
				log_error "Auto-detection failed. No shimboot partition found."
				exit 1
			fi
		else
			TARGET_PARTITION="$POSITIONAL_ARG"
			log_info "Using specified partition: $TARGET_PARTITION"
		fi
	else
		# No argument - try auto-detect or prompt
		if ! detect_partition; then
			log_info "Auto-detection failed. Select partition manually."
			if ! select_partition_manually; then
				log_error "No partition selected."
				exit 1
			fi
		fi
	fi

	# Validate partition exists
	validate_target_partition

	# Check and handle existing mounts
	if check_partition_mounted "$TARGET_PARTITION"; then
		if ! unmount_partition "$TARGET_PARTITION"; then
			log_error "Cannot proceed with mounted partition"
			exit 1
		fi
	fi

	log_info "Target partition: $TARGET_PARTITION"
	echo

	# Register cleanup traps
	register_traps

	# Mount system initially (read-only)
	mount_system "ro"

	# Enter main menu
	main_menu
}

main "$@"
