#!/usr/bin/env bash

# assemble-final.sh
#
# Purpose: Build and assemble final shimboot image with Nix outputs, drivers, and partitioning
#
# This module:
# - Orchestrates complete shimboot image creation
# - Builds Nix packages, harvests drivers, creates final disk image
# - Handles driver placement strategies (vendor/inject/both/none)
# - Manages workspace, loop devices, and partition layout

set -Eeuo pipefail

# Source shared libs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
# shellcheck source=logging.sh
source "$LIB_DIR/logging.sh"
# shellcheck source=runtime.sh
source "$LIB_DIR/runtime.sh"

# === Error Handler ===
handle_error() {
	local step="${1:-unknown}"
	local exit_code="${2:-1}"
	log_error "Step ${step} failed with exit code ${exit_code}"
	log_error "Workspace: ${WORKDIR:-not set}"
	log_error "Board: ${BOARD:-not set}"
	log_error "Rootfs flavor: ${ROOTFS_FLAVOR:-not set}"
	if [ -n "${LOOPDEV:-}" ]; then
		log_error "Loop device: ${LOOPDEV}"
	fi
	exit "${exit_code}"
}

# === Detect Rootfs Partition in EFI Raw Image ===
# EFI raw images have p1 as EFI (~1MB) and p2 as rootfs (~19GB)
# This function detects which partition contains the actual rootfs
detect_rootfs_partition() {
	local loopdev="${1:-}"
	local part_num=1

	if [ -z "$loopdev" ]; then
		echo "1"
		return
	fi

	# Check if p2 exists and has ext4 (likely rootfs)
	if [ -b "${loopdev}p2" ]; then
		# Use blkid to check filesystem type
		local fs_type
		fs_type=$(blkid -s TYPE -o value "${loopdev}p2" 2>/dev/null || echo "")
		if [ "$fs_type" = "ext4" ]; then
			part_num=2
		fi
	fi

	echo "$part_num"
}

# === Help Display ===
show_help() {
	cat <<'HELP'
Usage: ./assemble-final.sh [OPTIONS]

Options:
  -h, --help               Show this help message
  --board BOARD            Target board (dedede, octopus, etc.)
  --rootfs FLAVOR          Rootfs variant (full, minimal)
  --drivers MODE           Driver placement (vendor, inject, both, none)
  --firmware-upstream      Enable upstream firmware (default: 1)
  --no-firmware-upstream   Disable upstream firmware
  --inspect                Inspect final image after build
  --cleanup-rootfs         Clean up old rootfs generations
  --cleanup-keep N         Keep last N generations (default: 3)
  --cleanup-no-dry-run     Actually delete in cleanup (default: dry-run)
  --dry-run                Show what would be done without executing destructive operations (global)
  --prewarm-cache          Attempt to fetch from Cachix before building
  --push-to-cachix         Automatically push Nix derivations to Cachix after successful build
  --no-sudo                Skip sudo elevation (for testing or already-root users)

Examples:
  ./assemble-final.sh --board dedede --rootfs full
  ./assemble-final.sh --board dedede --rootfs minimal --drivers vendor --cleanup-rootfs
  ./assemble-final.sh --board dedede --rootfs full --dry-run
HELP
	exit 0
}

# === Early Argument Parsing (before sudo) ===
# Parse for --help and any flags that should work without sudo
HELP_MODE=0
SKIP_SUDO=0
REMAINING_ARGS=()

while [ $# -gt 0 ]; do
	case "${1:-}" in
	-h | --help)
		HELP_MODE=1
		shift
		;;
	--no-sudo)
		SKIP_SUDO=1
		shift
		;;
	*)
		REMAINING_ARGS+=("$1")
		shift
		;;
	esac
done

# Handle help display early (no sudo required)
if [ "$HELP_MODE" -eq 1 ]; then
	show_help
fi

# Restore args for further processing
set -- "${REMAINING_ARGS[@]}"

# === Initialize Config (before sudo) ===
BOARD="${BOARD:-}"
BOARD_EXPLICITLY_SET="${BOARD_EXPLICITLY_SET:-}"
ROOTFS_NAME="${ROOTFS_NAME:-nixos}"
ROOTFS_FLAVOR="${ROOTFS_FLAVOR:-}"
INSPECT_AFTER=""
DRY_RUN=0
FIRMWARE_UPSTREAM="${FIRMWARE_UPSTREAM:-1}"
CLEANUP_ROOTFS=0
CLEANUP_NO_DRY_RUN=0
CLEANUP_KEEP=""
PREWARM_CACHE="${PREWARM_CACHE:-0}"
PUSH_TO_CACHIX="${PUSH_TO_CACHIX:-0}"
DRIVERS_MODE="${DRIVERS_MODE:-}"

# === Main Argument Parsing (onboarding + args work together) ===
# If args provided, use them; otherwise prompt interactively
while [ $# -gt 0 ]; do
	case "${1:-}" in
	--board)
		BOARD="${2:-}"
		BOARD_EXPLICITLY_SET="set"
		shift 2
		;;
	--rootfs)
		ROOTFS_FLAVOR="${2:-}"
		shift 2
		;;
	--drivers)
		DRIVERS_MODE="${2:-vendor}"
		shift 2
		;;
	--firmware-upstream)
		FIRMWARE_UPSTREAM="1"
		shift
		;;
	--no-firmware-upstream)
		FIRMWARE_UPSTREAM="0"
		shift
		;;
	--inspect)
		INSPECT_AFTER="--inspect"
		shift
		;;
	--cleanup-rootfs)
		CLEANUP_ROOTFS=1
		shift
		;;
	--cleanup-no-dry-run)
		CLEANUP_NO_DRY_RUN=1
		shift
		;;
	--cleanup-keep | --keep)
		CLEANUP_KEEP="${2:-}"
		shift 2
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	--prewarm-cache)
		PREWARM_CACHE=1
		shift
		;;
	--push-to-cachix)
		PUSH_TO_CACHIX=1
		shift
		;;
	*)
		log_warn "Unknown option: ${1:-}"
		shift
		;;
	esac
done

# === Onboarding: Prompt for missing required args ===
# Board onboarding
if [ -z "$BOARD" ]; then
	if [ -t 0 ]; then
		echo
		echo "[assemble-final] No board specified. Available boards:"
		mapfile -t AVAILABLE_BOARDS < <(
			ls manifests/*-manifest.nix 2>/dev/null |
				sed 's|manifests/||;s|-manifest.nix||' | sort
		)
		for b in "${AVAILABLE_BOARDS[@]}"; do
			echo "  $b"
		done
		read -rp "Enter board name [default=dedede]: " BOARD
		BOARD="${BOARD:-dedede}"
		[ -n "$BOARD" ] && BOARD_EXPLICITLY_SET="set"
	else
		BOARD="dedede"
	fi
fi

# Rootfs flavor onboarding (mutually exclusive with --rootfs arg)
if [ -z "$ROOTFS_FLAVOR" ]; then
	if [ -t 0 ]; then
		echo
		echo "[assemble-final] Select rootfs flavor to build:"
		echo "  1) full     (recommended) -> complete desktop with Home Manager, Rose Pine theme, and user applications (~16-20GB)"
		echo "  2) minimal  (lightweight) -> base system with LightDM + Hyprland, network, and shell utilities (~6-8GB)"
		read -rp "Enter choice [1/2, default=1]: " choice
		case "${choice:-1}" in
		2) ROOTFS_FLAVOR="minimal" ;;
		*) ROOTFS_FLAVOR="full" ;;
		esac
	else
		ROOTFS_FLAVOR="full"
	fi
fi

# Drivers mode onboarding
if [ -z "$DRIVERS_MODE" ]; then
	if [ -t 0 ]; then
		echo
		echo "[assemble-final] Select driver mode:"
		echo "  1) vendor   (recommended) -> place drivers in separate vendor partition"
		echo "  2) inject  -> inject drivers directly into rootfs"
		echo "  3) both    -> vendor + inject (redundant but safe)"
		echo "  4) none    -> skip driver handling"
		read -rp "Enter choice [1/2/3/4, default=1]: " choice
		case "${choice:-1}" in
		2) DRIVERS_MODE="inject" ;;
		3) DRIVERS_MODE="both" ;;
		4) DRIVERS_MODE="none" ;;
		*) DRIVERS_MODE="vendor" ;;
		esac
	else
		DRIVERS_MODE="vendor"
	fi
fi

# Validate args after onboarding
if [ -z "$BOARD" ]; then
	echo "[assemble-final] Error: Board name cannot be empty. Use --board <name>." >&2
	exit 1
fi

# Warn if board wasn't explicitly provided via arg
if [ -z "$BOARD_EXPLICITLY_SET" ]; then
	echo "[assemble-final] Warning: No --board specified; defaulting to '$BOARD'." >&2
	sleep 1
fi

# === Deferred Sudo Check (only when needed) ===
# Only require sudo for actual build operations, not for help/onboarding
require_sudo() {
	if [ "${SKIP_SUDO:-0}" -eq 1 ]; then
		log_info "sudo elevation skipped (--no-sudo specified)"
		return 0
	fi
	if [ "${EUID:-$(id -u)}" -ne 0 ]; then
		echo "[assemble-final] Re-executing with sudo -H..."
		echo "[assemble-final] Please enter your sudo password when prompted..."
		SUDO_ENV=()
		for var in BOARD BOARD_EXPLICITLY_SET CACHIX_AUTH_TOKEN ROOTFS_FLAVOR DRIVERS_MODE \
			FIRMWARE_UPSTREAM DRY_RUN INSPECT_AFTER CLEANUP_ROOTFS CLEANUP_NO_DRY_RUN \
			CLEANUP_KEEP PREWARM_CACHE PUSH_TO_CACHIX; do
			if [ -n "${!var:-}" ]; then SUDO_ENV+=("$var=${!var}"); fi
		done
		exec sudo -E -H "${SUDO_ENV[@]}" "$0" --no-sudo "$@"
	fi
}

# === CI Detection ===
is_ci() {
	[ "${CI:-}" = "true" ] ||
		[ -n "${GITHUB_ACTIONS:-}" ] ||
		[ -n "${GITLAB_CI:-}" ] ||
		[ -n "${JENKINS_HOME:-}" ]
}

# === Colors & Logging ===
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'

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
	printf "${ANSI_RED}  X %s${ANSI_CLEAR}\n" "$1"
}

log_success() {
	printf "${ANSI_GREEN}  OK %s${ANSI_CLEAR}\n" "$1"
}

# === Cachix Configuration (fixed cache, CI-safe) ===
CACHIX_CACHE="shimboot-systemd-nixos"
CACHIX_PUBKEY="shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
export CACHIX_CACHE CACHIX_PUBKEY

# Enable caching if cachix is available
if command -v cachix >/dev/null 2>&1; then
	log_info "Using Cachix cache: ${CACHIX_CACHE}"

	# Authenticate if token is provided (recommended for CI)
	if [ -n "${CACHIX_AUTH_TOKEN:-}" ]; then
		cachix authtoken "$CACHIX_AUTH_TOKEN" 2>/dev/null || true
	fi

	# Configure trusted cache only if writable (skip on NixOS read-only systems)
	if [ -w /etc/nix/nix.conf ] 2>/dev/null; then
		mkdir -p /etc/nix
		if ! grep -q "$CACHIX_CACHE" /etc/nix/nix.conf 2>/dev/null; then
			echo "substituters = https://cache.nixos.org https://${CACHIX_CACHE}.cachix.org" | sudo tee -a /etc/nix/nix.conf >/dev/null
			echo "trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= ${CACHIX_PUBKEY}" | sudo tee -a /etc/nix/nix.conf >/dev/null
			log_info "Configured nix.conf for Cachix trust"
		fi
	elif [ -f /etc/nix/nix.conf ]; then
		log_info "nix.conf is read-only (NixOS); cache should be configured in system config"
	else
		log_warn "nix.conf not accessible; ensure Cachix is configured via NixOS config or user settings"
	fi
else
	log_warn "cachix CLI not installed; skipping cache integration"
fi

# Add after Cachix configuration section in assemble-final.sh
verify_cachix_config() {
	log_step "Pre-check" "Verifying Cachix configuration"

	# Check if Cachix is in substituters
	if nix config show | grep -q "shimboot-systemd-nixos.cachix.org"; then
		log_info "OK Cachix configured in Nix settings"
	else
		log_warn "Cachix not found in Nix settings; builds may not use cache"
		log_warn "This is normal if using flake-based config"
	fi

	# Test Cachix connectivity
	if command -v curl >/dev/null 2>&1; then
		if curl -sf "https://${CACHIX_CACHE}.cachix.org/nix-cache-info" >/dev/null; then
			log_info "OK Cachix endpoint reachable"
		else
			log_warn "Cannot reach Cachix endpoint; falling back to local builds"
		fi
	fi

	# Show current substituters
	log_info "Active substituters:"
	nix config show | grep "^substituters" | sed 's/^/    /'
}

# Ensure unfree packages are allowed for nix builds that require ChromeOS tools/firmware
export NIXPKGS_ALLOW_UNFREE="${NIXPKGS_ALLOW_UNFREE:-1}"

# === Setup Workspace Path (Now that BOARD is known) ===
# Detect if in CI with Nothing but Nix (large /nix mount)
if [ -d "/nix" ] && mountpoint -q /nix 2>/dev/null; then
	# Check if /nix has >50GB free (indicates CI environment)
	NIX_AVAIL_GB=$(df -BG /nix | awk 'NR==2 {print $4}' | sed 's/G//')
	if [ "${NIX_AVAIL_GB:-0}" -gt 50 ]; then
		# FIX: Append BOARD to path to prevent matrix collisions
		WORKDIR="/nix/work/${BOARD}"
		log_info "CI mode detected: using ${WORKDIR} (${NIX_AVAIL_GB}GB available)"
	else
		WORKDIR="$(pwd)/work/${BOARD}"
	fi
else
	WORKDIR="$(pwd)/work/${BOARD}"
fi

IMAGE="$WORKDIR/shimboot.img"

# Validate rootfs flavor
if [ "${ROOTFS_FLAVOR}" != "full" ] && [ "${ROOTFS_FLAVOR}" != "minimal" ]; then
	echo "[assemble-final] Error: Invalid --rootfs value: '${ROOTFS_FLAVOR}'. Use 'full' or 'minimal'." >&2
	exit 1
fi

# Build raw-rootfs attribute name based on flavor
RAW_ROOTFS_ATTR="raw-rootfs"
if [ "${ROOTFS_FLAVOR}" = "minimal" ]; then
	RAW_ROOTFS_ATTR="raw-rootfs-minimal"
fi

# Only print summary in elevated context to avoid double output on sudo re-exec
if [ "${SKIP_SUDO:-0}" -eq 1 ]; then
	log_info "Rootfs flavor: ${ROOTFS_FLAVOR} (attr: .#${RAW_ROOTFS_ATTR})"
	log_info "Board: ${BOARD}"
	log_info "Drivers mode: ${DRIVERS_MODE:-vendor} (vendor|inject|none)"
	log_info "Upstream firmware: ${FIRMWARE_UPSTREAM} (0=disabled, 1=enabled)"
	log_info "Push to Cachix: ${PUSH_TO_CACHIX} (0=disabled, 1=enabled, derivations only)"
	if [ "$DRY_RUN" -eq 1 ]; then
		log_warn "DRY RUN MODE: No destructive operations will be performed"
	fi
fi

# === Safe execution wrapper for destructive operations ===
safe_exec() {
	if [ "$DRY_RUN" -eq 1 ]; then
		log_info "[DRY-RUN] Would execute: $*"
	else
		"$@"
	fi
}

# === Require sudo before first destructive operation ===
require_sudo

# === Cleanup workspace ===
if [ -d "$WORKDIR" ]; then
	log_info "Cleaning up old work directory..."
	# Detach any loops left over from a previous run before unlinking the files;
	# otherwise the backing files become '(deleted)' and the loop persists until reboot.
	while read -r _stale_dev; do
		[ -n "$_stale_dev" ] || continue
		log_info "Detaching stale loop device $_stale_dev from previous run..."
		sudo losetup -d "$_stale_dev" 2>/dev/null || true
	done < <(losetup -l --noheadings -O NAME,BACK-FILE 2>/dev/null |
		awk -v d="$WORKDIR" '$2 ~ "^" d {print $1}')
	unset _stale_dev
	safe_exec sudo rm -rf "$WORKDIR"
fi
mkdir -p "$WORKDIR" "$WORKDIR/mnt_src_rootfs" "$WORKDIR/mnt_bootloader" "$WORKDIR/mnt_rootfs"

# Add after workspace creation (before Step 1)
check_disk_space() {
	local required_gb="${1:-30}"
	local path="${2:-.}"
	local available_gb
	available_gb=$(df -BG "$path" | awk 'NR==2 {print $4}' | sed 's/G//')

	if [ "${available_gb:-0}" -lt "$required_gb" ]; then
		log_error "Insufficient disk space: ${available_gb}GB available, ${required_gb}GB required"
		log_error "Free up space or use --workdir /path/to/larger/partition"
		exit 1
	fi
	log_info "Disk space check: ${available_gb}GB available (${required_gb}GB required)"
}

# Usage
check_disk_space 30 "$(dirname "$WORKDIR")"

# === Track loop devices for cleanup ===
LOOPDEV=""
LOOPROOT=""

cleanup_loop_devices() {
	log_info "Cleaning up loop devices..."

	# Detach loops for all known backing files in the workspace
	local backing_files=()
	[ -f "$IMAGE" ] && backing_files+=("$IMAGE")
	[ -f "$WORKDIR/rootfs.img" ] && backing_files+=("$WORKDIR/rootfs.img")

	for f in "${backing_files[@]}"; do
		while read -r dev; do
			[ -n "$dev" ] || continue
			log_info "Detaching $dev (backed by $(basename "$f"))..."
			sudo losetup -d "$dev" 2>/dev/null || sudo losetup -d "$dev" -f 2>/dev/null || true
		done < <(losetup -j "$f" 2>/dev/null | cut -d: -f1)
	done

	# Explicit cleanup of tracked devices (fallback if backing file was already removed)
	for dev in "$LOOPDEV" "$LOOPROOT"; do
		if [ -n "$dev" ] && losetup "$dev" &>/dev/null; then
			log_info "Detaching tracked device $dev..."
			sudo losetup -d "$dev" 2>/dev/null || true
		fi
	done
}

# Update main cleanup function
cleanup() {
	log_info "Cleanup: unmounting and detaching loop devices..."
	set +e

	# Unmount with retries
	for mnt in "$WORKDIR/mnt_rootfs" "$WORKDIR/mnt_bootloader" \
		"$WORKDIR/mnt_src_rootfs" "$WORKDIR/inspect_rootfs" \
		"$WORKDIR/mnt_vendor"; do
		if mountpoint -q "$mnt" 2>/dev/null; then
			log_info "Unmounting $mnt..."
			for i in {1..3}; do
				safe_exec sudo umount "$mnt" 2>/dev/null && break
				sleep 0.5
				[ "$i" -eq 3 ] && safe_exec sudo umount -l "$mnt" 2>/dev/null
			done
		fi
	done

	sync
	sleep 1 # Give kernel time to settle

	cleanup_loop_devices

	# Remove working subdirectories; preserve the final image
	for d in mnt_rootfs mnt_bootloader mnt_src_rootfs mnt_vendor inspect_rootfs \
		harvested linux-firmware.upstream; do
		rm -rf "${WORKDIR:?}/$d" 2>/dev/null || true
	done

	set -e
}
# Handle user keyboard interrupt gracefully
handle_interrupt() {
	echo
	log_warn "Keyboard interrupt detected (Ctrl+C)"
	log_warn "Cleaning up in-progress mounts and loop devices..."

	# Prevent recursive triggers while cleaning up
	trap - INT

	# Attempt graceful cleanup
	cleanup

	log_error "Assembly interrupted by user."
	exit 130 # 130 = 128 + SIGINT
}

# Normal cleanup on script exit or termination
trap cleanup EXIT TERM
# Handle manual user interrupt
trap handle_interrupt INT

# === Retry Logic ===
retry_command() {
	local max_attempts="${1:-3}"
	local wait_time="${2:-5}"
	shift 2
	local attempt=1

	while [ "$attempt" -le "$max_attempts" ]; do
		log_info "Attempt $attempt/$max_attempts: $*"
		if "$@"; then
			return 0
		fi

		local exit_code=$?
		if [ "$attempt" -lt "$max_attempts" ]; then
			log_warn "Command failed with exit code $exit_code, retrying in ${wait_time}s..."
			sleep "$wait_time"
		else
			log_error "Command failed after $max_attempts attempts"
			return $exit_code
		fi

		((attempt++))
	done
}

# === Nix Build Flags Configuration ===
if is_ci; then
	NIX_BUILD_FLAGS=(
		--impure
		--accept-flake-config
		--max-jobs auto
		--cores 0       # Use all cores
		--log-lines 100 # Limit log spam in CI
	)
else
	NIX_BUILD_FLAGS=(
		--impure
		--accept-flake-config
		--keep-going # Try to build as much as possible
		--fallback   # Fallback to local build if substituter fails
	)
fi

# Call before Step 1
verify_cachix_config

# Add before Step 1
if [ "$PREWARM_CACHE" -eq 1 ]; then
	log_step "Pre-warm" "Attempting to fetch from Cachix"

	# Try to substitute without building
	nix build --dry-run \
		."#extracted-kernel-${BOARD}" \
		."#initramfs-patching-${BOARD}" \
		."#${RAW_ROOTFS_ATTR}" \
		2>&1 | grep "will be fetched" || log_info "Nothing to fetch"
fi

# === Step 1: Build Nix outputs (parallel) ===
CURRENT_STEP="1/17"
log_step "$CURRENT_STEP" "Building Nix outputs (parallel)"

# Build all in parallel, capture PIDs
nix build "${NIX_BUILD_FLAGS[@]}" ."#extracted-kernel-${BOARD}" &
KERNEL_PID=$!
nix build "${NIX_BUILD_FLAGS[@]}" ."#initramfs-patching-${BOARD}" &
INITRAMFS_PID=$!
nix build "${NIX_BUILD_FLAGS[@]}" ."#${RAW_ROOTFS_ATTR}" &
ROOTFS_PID=$!

# Wait and check each
wait $KERNEL_PID || {
	log_error "Kernel build failed"
	handle_error "$CURRENT_STEP"
}
wait $INITRAMFS_PID || {
	log_error "Initramfs build failed"
	handle_error "$CURRENT_STEP"
}
wait $ROOTFS_PID || {
	log_error "Rootfs build failed"
	handle_error "$CURRENT_STEP"
}

# Get paths (instant since already built)
ORIGINAL_KERNEL="$(nix build --impure --accept-flake-config ".#extracted-kernel-${BOARD}" --print-out-paths)/p2.bin"
PATCHED_INITRAMFS="$(nix build --impure --accept-flake-config ".#initramfs-patching-${BOARD}" --print-out-paths)/patched-initramfs"
# Resolve rootfs image from derivation output with three-tier fallback
RAW_ROOTFS_OUT="$(nix build --impure --accept-flake-config ".#${RAW_ROOTFS_ATTR}" --print-out-paths)"
if [ -f "$RAW_ROOTFS_OUT/nixos.img" ]; then
	RAW_ROOTFS_IMG="$RAW_ROOTFS_OUT/nixos.img"
elif [ -f "$RAW_ROOTFS_OUT" ]; then
	RAW_ROOTFS_IMG="$RAW_ROOTFS_OUT"
else
	RAW_ROOTFS_IMG="$(find "$RAW_ROOTFS_OUT" -maxdepth 2 -name '*.img' -type f | head -n1)"
	if [ -z "$RAW_ROOTFS_IMG" ]; then
		log_error "No .img file found in rootfs derivation output: $RAW_ROOTFS_OUT"
		ls -laR "$RAW_ROOTFS_OUT"
		handle_error "$CURRENT_STEP"
	fi
	log_info "Discovered rootfs image at non-standard path: $RAW_ROOTFS_IMG"
fi

# Validate build results
if [ ! -f "$ORIGINAL_KERNEL" ]; then
	log_error "Kernel binary build failed or missing: $ORIGINAL_KERNEL"
	handle_error "$CURRENT_STEP"
fi

log_info "Original kernel p2: $ORIGINAL_KERNEL"
log_info "Patched initramfs dir: $PATCHED_INITRAMFS"
log_info "Raw rootfs: $RAW_ROOTFS_IMG"

# Build ChromeOS SHIM and RECOVERY (always build recovery for Cachix caching)
SHIM_BIN="$(nix build "${NIX_BUILD_FLAGS[@]}" ."#chromeos-shim-${BOARD}" --print-out-paths)"
RECOVERY_BIN_PATH="$(nix build "${NIX_BUILD_FLAGS[@]}" ."#chromeos-recovery-${BOARD}" --print-out-paths)"
RECOVERY_PATH=""
if [ "${SKIP_RECOVERY:-0}" != "1" ]; then
	if [ -n "${RECOVERY_BIN:-}" ]; then
		RECOVERY_PATH="$RECOVERY_BIN"
	else
		RECOVERY_PATH="$RECOVERY_BIN_PATH/recovery.bin"
	fi
fi
log_info "ChromeOS shim: $SHIM_BIN"
log_info "ChromeOS recovery derivation: $RECOVERY_BIN_PATH"
if [ -n "$RECOVERY_PATH" ]; then
	log_info "Recovery image: $RECOVERY_PATH"
else
	log_info "Recovery image: skipped (SKIP_RECOVERY=1 or not provided)"
fi

# === Step 2: Harvest ChromeOS drivers (modules/firmware/modprobe.d) ===
HARVEST_OUT="$WORKDIR/harvested"
mkdir -p "$HARVEST_OUT"
CURRENT_STEP="2/17"
log_step "$CURRENT_STEP" "Harvest ChromeOS drivers"
if [ -n "$RECOVERY_PATH" ]; then
	bash tools/build/harvest-drivers.sh --shim "$SHIM_BIN" --recovery "$RECOVERY_PATH" --out "$HARVEST_OUT" || {
		log_error "Driver harvest failed with recovery image"
		handle_error "$CURRENT_STEP"
	}
else
	bash tools/build/harvest-drivers.sh --shim "$SHIM_BIN" --out "$HARVEST_OUT" || {
		log_error "Driver harvest failed without recovery image"
		handle_error "$CURRENT_STEP"
	}
fi

# Detach any loops left by harvest-drivers.sh (shim/recovery are Nix store files)
for _img in "$SHIM_BIN" "$RECOVERY_PATH"; do
	[ -f "$_img" ] || continue
	while read -r _dev; do
		[ -n "$_dev" ] && sudo losetup -d "$_dev" 2>/dev/null || true
	done < <(losetup -j "$_img" 2>/dev/null | cut -d: -f1)
done
unset _img _dev

# === Step 3: Augment firmware with upstream ChromiumOS linux-firmware ===
if [ "${FIRMWARE_UPSTREAM:-1}" != "0" ]; then
	CURRENT_STEP="3/17"
	log_step "$CURRENT_STEP" "Augment firmware with upstream linux-firmware"
	log_info "Cloning upstream linux-firmware repository..."
	UPSTREAM_FW_DIR="$WORKDIR/linux-firmware.upstream"
	if [ ! -d "$UPSTREAM_FW_DIR" ]; then
		# Shallow clone to reduce time/size
		git clone --depth=1 https://chromium.googlesource.com/chromiumos/third_party/linux-firmware "$UPSTREAM_FW_DIR" || true
	fi
	log_info "Merging upstream firmware with harvested firmware..."
	mkdir -p "$HARVEST_OUT/lib/firmware"
	# Merge, preserving attributes; ignore errors on collisions
	sudo cp -a "$UPSTREAM_FW_DIR/." "$HARVEST_OUT/lib/firmware/" 2>/dev/null || true
	log_info "Upstream firmware augmentation complete"
else
	log_info "Upstream firmware disabled, using only harvested firmware"
fi

# === Step 4: Prune unused firmware files ===
if [ -d "$HARVEST_OUT/lib/firmware" ]; then
	CURRENT_STEP="4/17"
	log_step "$CURRENT_STEP" "Prune unused firmware files"
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	if [ -f "$SCRIPT_DIR/prune-firmware.sh" ]; then
		# shellcheck disable=SC1091
		source "$SCRIPT_DIR/prune-firmware.sh"
		prune_unused_firmware "$HARVEST_OUT/lib/firmware"
	else
		log_warn "prune-firmware.sh not found; skipping firmware pruning"
	fi
fi

# === Step 5: Calculate vendor partition size AFTER firmware augmentation ===
CURRENT_STEP="5/17"
log_step "$CURRENT_STEP" "Calculate vendor partition size after firmware merge"
VENDOR_SRC_SIZE_MB=0
if [ -d "$HARVEST_OUT/lib/modules" ]; then
	VENDOR_SRC_SIZE_MB=$((VENDOR_SRC_SIZE_MB + $(sudo du -sm "$HARVEST_OUT/lib/modules" | cut -f1)))
fi
if [ -d "$HARVEST_OUT/lib/firmware" ]; then
	VENDOR_SRC_SIZE_MB=$((VENDOR_SRC_SIZE_MB + $(sudo du -sm "$HARVEST_OUT/lib/firmware" | cut -f1)))
fi

# Add 15% overhead + small safety cushion
VENDOR_PART_SIZE=$(((VENDOR_SRC_SIZE_MB * 115 / 100) + 20))
log_info "Vendor partition size (post-firmware): ${VENDOR_PART_SIZE} MB"

# === Step 6: Copy raw rootfs image ===
CURRENT_STEP="6/17"
log_step "$CURRENT_STEP" "Copy raw rootfs image"
if [ ! -f "$RAW_ROOTFS_IMG" ]; then
	log_error "Raw rootfs image is not a file: $RAW_ROOTFS_IMG"
	handle_error "$CURRENT_STEP"
fi
pv "$RAW_ROOTFS_IMG" >"$WORKDIR/rootfs.img"

# === Step 7: Optimize Nix store in raw rootfs ===
CURRENT_STEP="7/17"
log_step "$CURRENT_STEP" "Optimize Nix store in raw rootfs"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img") || {
	log_error "Failed to setup loop device for rootfs optimization"
	handle_error "$CURRENT_STEP"
}
RAW_ROOTFS_PART=$(detect_rootfs_partition "$LOOPROOT")
log_info "Detected rootfs partition: p${RAW_ROOTFS_PART}"
safe_exec sudo mount "${LOOPROOT}p${RAW_ROOTFS_PART}" "$WORKDIR/mnt_src_rootfs" || {
	log_error "Failed to mount rootfs for optimization"
	handle_error "$CURRENT_STEP"
}
log_info "Running nix-store --optimise on raw rootfs (may take a while)..."
safe_exec sudo "$(which nix-store)" --store "$WORKDIR/mnt_src_rootfs" --optimise || true
log_info "Store optimization complete"
safe_exec sudo umount "$WORKDIR/mnt_src_rootfs"
safe_exec sudo losetup -d "$LOOPROOT"
LOOPROOT=""

# === Step 8: Calculate rootfs size ===
CURRENT_STEP="8/17"
log_step "$CURRENT_STEP" "Calculate rootfs size"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
RAW_ROOTFS_PART=$(detect_rootfs_partition "$LOOPROOT")
safe_exec sudo mount "${LOOPROOT}p${RAW_ROOTFS_PART}" "$WORKDIR/mnt_src_rootfs"
ROOTFS_SIZE_MB=$(sudo du -sm "$WORKDIR/mnt_src_rootfs" | cut -f1)
log_info "Rootfs content size: ${ROOTFS_SIZE_MB} MB"

# Sanity check: fail if rootfs is suspiciously small
if [ "$ROOTFS_SIZE_MB" -lt 500 ]; then
	log_error "Rootfs size (${ROOTFS_SIZE_MB} MB) is suspiciously small (expected >500 MB)"
	log_error "This may indicate the wrong partition was mounted (EFI vs rootfs)"
	handle_error "$CURRENT_STEP"
fi

safe_exec sudo umount "$WORKDIR/mnt_src_rootfs"
safe_exec sudo losetup -d "$LOOPROOT"
LOOPROOT=""

# Add 10% growth margin, at least 100 MiB spare
ROOTFS_PART_SIZE=$(((ROOTFS_SIZE_MB * 110 / 100) + 100))
log_info "Rootfs partition size: ${ROOTFS_PART_SIZE} MB (with safety margin)"

# Compute end of vendor and total size (MiB)
# NEW LAYOUT: vendor comes before rootfs
VENDOR_START_MB=54
VENDOR_END_MB=$((VENDOR_START_MB + VENDOR_PART_SIZE))
TOTAL_SIZE_MB=$((1 + 32 + 20 + VENDOR_PART_SIZE + ROOTFS_PART_SIZE))
log_info "Vendor partition size: ${VENDOR_PART_SIZE} MB"
log_info "Rootfs partition size: ${ROOTFS_PART_SIZE} MB (initial, expandable)"
log_info "Total image size: ${TOTAL_SIZE_MB} MB"

# === Step 9: Create empty image ===
CURRENT_STEP="9/17"
log_step "$CURRENT_STEP" "Create empty image"
fallocate -l ${TOTAL_SIZE_MB}M "$IMAGE"

# === Partition Layout Logic ===
if [ "$DRIVERS_MODE" = "inject" ]; then
	HAS_VENDOR_PARTITION=0
	ROOTFS_PARTITION_INDEX=4
	log_info "Inject mode: skipping vendor partition (rootfs -> p4)"
else
	HAS_VENDOR_PARTITION=1
	ROOTFS_PARTITION_INDEX=5
	log_info "Vendor mode: keeping vendor partition (rootfs -> p5)"
fi

# === Step 10: Partition image ===
CURRENT_STEP="10/17"
log_step "$CURRENT_STEP" "Partition image (GPT, ChromeOS GUIDs, vendor before rootfs)"
if [ "$HAS_VENDOR_PARTITION" -eq 1 ]; then
	log_info "Partition layout: vendor (p4), rootfs (p5)"
	log_info "  p1: STATE (1–2 MiB)"
	log_info "  p2: KERNEL (2–34 MiB, ChromeOS kernel)"
	log_info "  p3: BOOT (34–54 MiB, bootloader/initramfs)"
	log_info "  p4: VENDOR (${VENDOR_START_MB}–${VENDOR_END_MB} MiB, drivers/firmware)"
	log_info "  p5: ROOTFS (${VENDOR_END_MB} MiB–end, NixOS system)"

	parted --script "$IMAGE" \
		mklabel gpt \
		mkpart stateful ext4 1MiB 2MiB \
		name 1 STATE \
		mkpart kernel 2MiB 34MiB \
		name 2 KERNEL \
		type 2 FE3A2A5D-4F32-41A7-B725-ACCC3285A309 \
		mkpart bootloader ext2 34MiB 54MiB \
		name 3 BOOT \
		type 3 3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC \
		mkpart vendor ext4 ${VENDOR_START_MB}MiB ${VENDOR_END_MB}MiB \
		name 4 "shimboot_rootfs:vendor" \
		type 4 0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
		mkpart rootfs ext4 ${VENDOR_END_MB}MiB 100% \
		name 5 "shimboot_rootfs:${ROOTFS_NAME}" \
		type 5 3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC

else
	log_info "Partition layout: rootfs (p4), no vendor partition"
	log_info "  p1: STATE (1–2 MiB)"
	log_info "  p2: KERNEL (2–34 MiB, ChromeOS kernel)"
	log_info "  p3: BOOT (34–54 MiB, bootloader/initramfs)"
	log_info "  p4: ROOTFS (54 MiB–end, NixOS system)"

	parted --script "$IMAGE" \
		mklabel gpt \
		mkpart stateful ext4 1MiB 2MiB \
		name 1 STATE \
		mkpart kernel 2MiB 34MiB \
		name 2 KERNEL \
		type 2 FE3A2A5D-4F32-41A7-B725-ACCC3285A309 \
		mkpart bootloader ext2 34MiB 54MiB \
		name 3 BOOT \
		type 3 3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC \
		mkpart rootfs ext4 54MiB 100% \
		name 4 "shimboot_rootfs:${ROOTFS_NAME}" \
		type 4 3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC
fi

log_info "Partition table:"
sudo partx -o NR,START,END,SIZE,TYPE,NAME,UUID -g --show "$IMAGE"

# === Step 11: Setup loop device ===
CURRENT_STEP="11/17"
log_step "$CURRENT_STEP" "Setup loop device"
LOOPDEV=$(sudo losetup --show -fP "$IMAGE") || {
	log_error "Failed to setup loop device for $IMAGE"
	handle_error "$CURRENT_STEP"
}
log_info "Loop device: $LOOPDEV"

# Ensure cgpt is available
if ! command -v cgpt >/dev/null 2>&1; then
	log_info "cgpt not found in PATH, searching in Nix store..."
	# Find cgpt in Nix store
	CGPT_PATH=$(find /nix/store -name "cgpt" -type f -executable 2>/dev/null | grep vboot_reference | head -n1)
	if [ -n "$CGPT_PATH" ]; then
		log_info "Found cgpt at: $CGPT_PATH"
		# Create a temporary wrapper to ensure cgpt is available
		CGPT_DIR=$(dirname "$CGPT_PATH")
		export PATH="$CGPT_DIR:${PATH}"
	else
		log_error "cgpt not found in Nix store. Please ensure vboot_reference is installed."
		log_error "Try running: nix develop"
		handle_error "$CURRENT_STEP"
	fi
fi

# Set ChromeOS boot flags on p2
log_info "Setting ChromeOS boot flags on KERNEL partition..."
safe_exec sudo cgpt add -i 2 -S 1 -T 5 -P 10 "$LOOPDEV" || {
	log_error "Failed to set ChromeOS boot flags"
	handle_error "$CURRENT_STEP"
}

# === Step 12: Format partitions ===
CURRENT_STEP="12/17"
log_step "$CURRENT_STEP" "Format partitions"
# Use conservative ext4 features for ChromeOS kernel compatibility (avoid EINVAL on mount)
MKFS_EXT4_FLAGS=(-O ^orphan_file,^metadata_csum_seed)
safe_exec sudo mkfs.ext4 -q "${MKFS_EXT4_FLAGS[@]}" "${LOOPDEV}p1"
safe_exec sudo dd if="$ORIGINAL_KERNEL" of="${LOOPDEV}p2" bs=1M conv=fsync status=progress
safe_exec sudo mkfs.ext2 -q "${LOOPDEV}p3"

if [ "$HAS_VENDOR_PARTITION" -eq 1 ]; then
	# Vendor partition (drivers/firmware donor) - p4
	safe_exec sudo mkfs.ext4 -q -O ^has_journal,^orphan_file,^metadata_csum_seed \
		-L "shimboot_vendor" "${LOOPDEV}p4"
	# Rootfs is p5
	safe_exec sudo mkfs.ext4 -q -L "$ROOTFS_NAME" "${MKFS_EXT4_FLAGS[@]}" "${LOOPDEV}p5"
else
	# Rootfs directly as p4
	safe_exec sudo mkfs.ext4 -q -L "$ROOTFS_NAME" "${MKFS_EXT4_FLAGS[@]}" "${LOOPDEV}p4"
fi

# After Step 12: Format partitions
log_info "Verifying partition formatting..."
if [ "$HAS_VENDOR_PARTITION" -eq 1 ]; then
	for part in p1 p2 p3 p4 p5; do
		if [ ! -b "${LOOPDEV}${part}" ]; then
			log_error "Partition ${part} not found after formatting"
			handle_error "$CURRENT_STEP"
		fi
	done
else
	for part in p1 p2 p3 p4; do
		if [ ! -b "${LOOPDEV}${part}" ]; then
			log_error "Partition ${part} not found after formatting"
			handle_error "$CURRENT_STEP"
		fi
	done
fi

# === Step 13: Populate bootloader partition ===
CURRENT_STEP="13/17"
log_step "$CURRENT_STEP" "Populate bootloader partition"
safe_exec sudo mount "${LOOPDEV}p3" "$WORKDIR/mnt_bootloader" || {
	log_error "Failed to mount bootloader partition"
	handle_error "$CURRENT_STEP"
}
total_bytes=$(sudo du -sb "$PATCHED_INITRAMFS" | cut -f1)
(cd "$PATCHED_INITRAMFS" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_bootloader" && sudo tar xf -) || {
	log_error "Failed to populate bootloader partition"
	handle_error "$CURRENT_STEP"
}
safe_exec sudo umount "$WORKDIR/mnt_bootloader"

# === Step 14: Populate rootfs partition ===
CURRENT_STEP="14/17"
log_step "$CURRENT_STEP" "Populate rootfs partition (now p${ROOTFS_PARTITION_INDEX})"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
RAW_ROOTFS_PART=$(detect_rootfs_partition "$LOOPROOT")
log_info "Source rootfs partition: p${RAW_ROOTFS_PART}"
safe_exec sudo mount "${LOOPROOT}p${RAW_ROOTFS_PART}" "$WORKDIR/mnt_src_rootfs"
safe_exec sudo mount "${LOOPDEV}p${ROOTFS_PARTITION_INDEX}" "$WORKDIR/mnt_rootfs"
# Use partition block size for accurate pv progress (avoids >100% due to fs metadata)
total_bytes=$(blockdev --getsize64 "${LOOPROOT}p${RAW_ROOTFS_PART}")
(cd "$WORKDIR/mnt_src_rootfs" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_rootfs" && sudo tar xf -)

# Get username from userConfig
USERNAME="$(nix eval --impure --accept-flake-config --expr "(import ./shimboot_config/user-config.nix {}).user.username" --json | jq -r .)"
log_info "Using username from userConfig: $USERNAME"

# === Step 15/17: Clone nixos-config repository into rootfs ===
CURRENT_STEP="15/17"
log_step "$CURRENT_STEP" "Clone nixos-config repository into rootfs"
NIXOS_CONFIG_DEST="$WORKDIR/mnt_rootfs/home/${USERNAME}/nixos-config"

if command -v git >/dev/null 2>&1 && [ -d .git ]; then
	# Get current git branch/commit info
	GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
	GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
	GIT_STATUS=$(git status --porcelain | wc -l 2>/dev/null || echo "0")
	BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "unknown")

	# Remove existing nixos-config if it exists
	if [ -d "$NIXOS_CONFIG_DEST" ]; then
		log_info "Removing existing nixos-config directory"
		safe_exec sudo rm -rf "$NIXOS_CONFIG_DEST"
	fi

	# Clone the repository
	log_info "Cloning nixos-config repository..."
	safe_exec sudo git clone --no-local "$(pwd)" "$NIXOS_CONFIG_DEST"
	# Detect actual remote origin
	ACTUAL_REMOTE=$(git remote get-url origin 2>/dev/null || echo "https://github.com/PopCat19/nixos-shimboot.git")
	safe_exec sudo git -C "$NIXOS_CONFIG_DEST" remote set-url origin "$ACTUAL_REMOTE"

	# Switch to the same branch as the source repository
	if [ "$GIT_BRANCH" != "unknown" ]; then
		log_info "Switching to branch: $GIT_BRANCH"
		safe_exec sudo git -C "$NIXOS_CONFIG_DEST" checkout "$GIT_BRANCH" || log_warn "Failed to checkout branch $GIT_BRANCH"
	fi

	# Set ownership to user
	safe_exec sudo chown -R 1000:1000 "$NIXOS_CONFIG_DEST"

	# Create branch info file
	sudo tee "$NIXOS_CONFIG_DEST/.shimboot_branch" >/dev/null <<EOF
# Shimboot build information
BUILD_DATE=$BUILD_DATE
GIT_BRANCH=$GIT_BRANCH
GIT_COMMIT=$GIT_COMMIT
GIT_CHANGES=$GIT_STATUS
GIT_REMOTE=$GIT_REMOTE
EOF

	# Create detailed build metadata file
	sudo tee "$NIXOS_CONFIG_DEST/.shimboot_build_info" >/dev/null <<EOF
# Shimboot build metadata
BUILD_HOST=$(hostname)
BUILD_USER=$(whoami)
BUILD_DATE=$BUILD_DATE
BOARD=$BOARD
ROOTFS_FLAVOR=$ROOTFS_FLAVOR
DRIVERS_MODE=$DRIVERS_MODE
GIT_BRANCH=$GIT_BRANCH
GIT_COMMIT=$GIT_COMMIT
GIT_CHANGES=$GIT_STATUS
GIT_REMOTE=$GIT_REMOTE
EOF

	log_info "Cloned nixos-config: $GIT_BRANCH ($GIT_COMMIT) with $GIT_STATUS changes"
else
	log_warn "Git not available or not a git repository, skipping nixos-config clone"
fi

# Create build metadata
log_info "Creating build metadata..."
safe_exec sudo mkdir -p "$WORKDIR/mnt_rootfs/etc"
safe_exec sudo tee "$WORKDIR/mnt_rootfs/etc/shimboot-build.json" >/dev/null <<EOF
{
	 "build_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
	 "build_host": "$(hostname)",
	 "board": "$BOARD",
	 "rootfs_flavor": "$ROOTFS_FLAVOR",
	 "drivers_mode": "$DRIVERS_MODE",
	 "firmware_upstream": "$FIRMWARE_UPSTREAM",
	 "nix_version": "$(nix --version | head -n1)",
	 "script_version": "2.0",
	 "git_commit": "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)",
	 "image_size_mb": "$TOTAL_SIZE_MB"
}
EOF

# Source rootfs unmounted; target rootfs remains mounted briefly before finalization
safe_exec sudo umount "$WORKDIR/mnt_src_rootfs"
safe_exec sudo losetup -d "$LOOPROOT"
LOOPROOT=""

# === Step 15: Driver handling functions ===
# Extract functions first to eliminate code duplication

populate_vendor() {
	if [ ! -b "${LOOPDEV}p4" ]; then
		log_error "Vendor partition p4 not found on ${LOOPDEV}"
		handle_error "$CURRENT_STEP"
	fi

	log_step "16/17" "Populate vendor partition (p4) with harvested drivers (/lib/modules, /lib/firmware)"
	safe_exec sudo mkdir -p "$WORKDIR/mnt_vendor"
	safe_exec sudo mount "${LOOPDEV}p4" "$WORKDIR/mnt_vendor"
	safe_exec sudo mkdir -p "$WORKDIR/mnt_vendor/lib/modules" "$WORKDIR/mnt_vendor/lib/firmware"

	if [ -d "$HARVEST_OUT/lib/modules" ]; then
		log_info "Copying modules to vendor..."
		safe_exec sudo cp -a "$HARVEST_OUT/lib/modules/." "$WORKDIR/mnt_vendor/lib/modules/"
	else
		log_warn "No harvested lib/modules; nothing to place into vendor partition"
	fi

	if [ -d "$HARVEST_OUT/lib/firmware" ]; then
		log_info "Copying firmware to vendor..."
		safe_exec sudo cp -a "$HARVEST_OUT/lib/firmware/." "$WORKDIR/mnt_vendor/lib/firmware/"
	else
		log_warn "No harvested lib/firmware; nothing to place into vendor partition"
	fi

	safe_exec sudo sync
	safe_exec sudo umount "$WORKDIR/mnt_vendor"
}

inject_drivers() {
	log_step "16/17" "Inject drivers into rootfs (p${ROOTFS_PARTITION_INDEX}) (/lib/modules, /lib/firmware, modprobe.d)"
	if [ -d "$HARVEST_OUT/lib/modules" ]; then
		safe_exec sudo rm -rf "$WORKDIR/mnt_rootfs/lib/modules"
		safe_exec sudo mkdir -p "$WORKDIR/mnt_rootfs/lib"
		safe_exec sudo cp -a "$HARVEST_OUT/lib/modules" "$WORKDIR/mnt_rootfs/lib/modules"
	else
		log_warn "No harvested lib/modules; skipping module injection"
	fi
	if [ -d "$HARVEST_OUT/lib/firmware" ]; then
		safe_exec sudo mkdir -p "$WORKDIR/mnt_rootfs/lib/firmware"
		safe_exec sudo cp -a "$HARVEST_OUT/lib/firmware/." "$WORKDIR/mnt_rootfs/lib/firmware/"
	else
		log_warn "No harvested lib/firmware; skipping firmware injection"
	fi
	if [ -d "$HARVEST_OUT/modprobe.d" ]; then
		safe_exec sudo mkdir -p "$WORKDIR/mnt_rootfs/lib/modprobe.d" "$WORKDIR/mnt_rootfs/etc/modprobe.d"
		safe_exec sudo cp -a "$HARVEST_OUT/modprobe.d/." "$WORKDIR/mnt_rootfs/lib/modprobe.d/" 2>/dev/null || true
		safe_exec sudo cp -a "$HARVEST_OUT/modprobe.d/." "$WORKDIR/mnt_rootfs/etc/modprobe.d/" 2>/dev/null || true
	fi
}

# === Step 15: Handle driver placement strategy ===
# Modes:
#   vendor: Place drivers in separate vendor partition (p4) - mounted at boot
#   inject: Directly copy drivers into rootfs (p${ROOTFS_PARTITION_INDEX}) /lib/{modules,firmware}
#   both:   Populate vendor partition AND inject into rootfs (redundant but safe)
#   none:   Skip driver handling entirely
case "$DRIVERS_MODE" in
vendor | CROSDRV)
	populate_vendor
	;;
both)
	populate_vendor
	inject_drivers
	;;
inject)
	if [ "$HAS_VENDOR_PARTITION" -eq 1 ]; then
		populate_vendor
	else
		log_info "Skipping vendor partition creation (inject mode)"
	fi
	inject_drivers
	;;
none)
	log_info "DRIVERS_MODE=none; leaving rootfs unchanged"
	;;
*)
	log_warn "Unknown DRIVERS_MODE='${DRIVERS_MODE}', defaulting to vendor populate"
	populate_vendor
	;;
esac

# Unmount rootfs
safe_exec sudo umount "$WORKDIR/mnt_rootfs"

# Detach loop devices used for target image
safe_exec sudo losetup -d "$LOOPDEV"
LOOPDEV=""

# === Completion Summary ===
log_step "Done" "Build complete"
log_info "Image:   $IMAGE"
log_info "Size:    $(du -sh "$IMAGE" | cut -f1)"
log_info "Board:   $BOARD  |  Flavor: $ROOTFS_FLAVOR  |  Drivers: $DRIVERS_MODE"
log_info "Elapsed: $((SECONDS / 60))m $((SECONDS % 60))s"

# === Optional cleanup of old shimboot rootfs generations ===
if [ "${CLEANUP_ROOTFS:-0}" -eq 1 ]; then
	CURRENT_STEP="Cleanup"
	log_step "$CURRENT_STEP" "Pruning older shimboot rootfs generations"
	# Build arguments for cleanup script
	CLEANUP_CMD=(sudo bash tools/rescue/cleanup-shimboot-rootfs.sh --results-dir "$(pwd)")
	if [ -n "${CLEANUP_KEEP:-}" ]; then
		CLEANUP_CMD+=("--keep" "$CLEANUP_KEEP")
	fi
	if [ "${CLEANUP_NO_DRY_RUN:-0}" -eq 1 ]; then
		CLEANUP_CMD+=("--no-dry-run")
	else
		CLEANUP_CMD+=("--dry-run")
	fi
	"${CLEANUP_CMD[@]}"
fi

# === Automatic Cachix push ===
if [ "$PUSH_TO_CACHIX" -eq 1 ]; then
	log_step "Cachix" "Pushing Nix derivations to Cachix (shim, recovery, kernel, initramfs, rootfs, chunks)..."

	# Check if push script exists
	if [ -f "tools/build/push-to-cachix.sh" ]; then
		# Check if cachix command is available
		if command -v cachix >/dev/null 2>&1; then
			# Check for CACHIX_AUTH_TOKEN in CI environments
			if is_ci && [ -z "${CACHIX_AUTH_TOKEN:-}" ]; then
				log_warn "CACHIX_AUTH_TOKEN not set in CI environment"
				log_warn "Set it to enable automatic pushing to Cachix"
			else
				log_info "Executing: ./tools/build/push-to-cachix.sh --board $BOARD --rootfs $ROOTFS_FLAVOR"
				if bash ./tools/build/push-to-cachix.sh --board "$BOARD" --rootfs "$ROOTFS_FLAVOR"; then
					log_success "Successfully pushed Nix derivations to Cachix"
				else
					log_error "Failed to push Nix derivations to Cachix"
					log_error "You can manually retry with:"
					log_error "  ./tools/build/push-to-cachix.sh --board $BOARD --rootfs $ROOTFS_FLAVOR"
				fi
			fi
		else
			log_warn "cachix command not found; skipping automatic push"
			log_warn "Install cachix to enable automatic pushing"
		fi
	else
		log_warn "push-to-cachix.sh script not found; skipping automatic push"
	fi
else
	# Show manual instruction only if not auto-pushing
	log_info "To push Nix derivations to Cachix (shim, recovery, kernel, initramfs, rootfs, chunks), run:"
	log_info "  ./tools/build/push-to-cachix.sh --board $BOARD --rootfs $ROOTFS_FLAVOR"
fi

# === Optional inspection ===
if [ "$INSPECT_AFTER" = "--inspect" ]; then
	CURRENT_STEP="Inspect"
	log_step "$CURRENT_STEP" "Partition table and init check"
	safe_exec sudo partx -o NR,START,END,SIZE,TYPE,NAME,UUID -g --show "$IMAGE"
	LOOPDEV=$(sudo losetup --show -fP "$IMAGE")
	mkdir -p "$WORKDIR/inspect_rootfs"
	safe_exec sudo mount "${LOOPDEV}p${ROOTFS_PARTITION_INDEX}" "$WORKDIR/inspect_rootfs"
	sudo ls -l "$WORKDIR/inspect_rootfs"
	if [ -f "$WORKDIR/inspect_rootfs/sbin/init" ]; then
		log_info "Init found at /sbin/init: $(file -b "$WORKDIR/inspect_rootfs/sbin/init")"
	elif [ -f "$WORKDIR/inspect_rootfs/init" ]; then
		log_info "Init found at /init: $(file -b "$WORKDIR/inspect_rootfs/init")"
	else
		log_error "Init missing"
	fi
	safe_exec sudo umount "$WORKDIR/inspect_rootfs"
	safe_exec sudo losetup -d "$LOOPDEV"
fi
