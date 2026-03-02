#!/usr/bin/env bash

# Assemble Final Script
#
# Purpose: Build and assemble final shimboot image with Nix outputs, drivers, and partitioning
# Dependencies: nix, sudo, parted, mkfs.ext4, dd, pv, losetup, mount, umount, cgpt
# Related: write-shimboot-image.sh, harvest-drivers.sh
#
# This script orchestrates the complete shimboot image creation process,
# building Nix packages, harvesting drivers, and creating the final disk image.
#
# Usage:
#   ./assemble-final.sh [OPTIONS]
#
# Options:
#   --board BOARD          Target board (dedede, octopus, etc.)
#   --rootfs FLAVOR        Rootfs variant (full, minimal)
#   --drivers MODE         Driver placement (vendor, inject, both, none)
#   --firmware-upstream    Enable upstream firmware (default: 1)
#   --no-firmware-upstream Disable upstream firmware
#   --inspect              Inspect final image after build
#   --cleanup-rootfs       Clean up old rootfs generations
#   --cleanup-keep N       Keep last N generations (default: 3)
#   --no-dry-run           Actually delete in cleanup (default: dry-run)
#   --dry-run              Show what would be done without executing destructive operations
#   --prewarm-cache        Attempt to fetch from Cachix before building
#   --push-to-cachix       Automatically push Nix derivations to Cachix after successful build (image upload no longer supported)
#
# Examples:
#   # Build dedede with full rootfs
#   ./assemble-final.sh --board dedede --rootfs full
#
#   # Build with vendor drivers and cleanup
#   ./assemble-final.sh --board dedede --rootfs minimal --drivers vendor --cleanup-rootfs --cleanup-keep 2 --no-dry-run
#
#   # Dry run to see what would be executed
#   ./assemble-final.sh --board dedede --rootfs full --dry-run
#
#   # Build with cache pre-warming
#   ./assemble-final.sh --board dedede --rootfs full --prewarm-cache
#
#   # Build and automatically push Nix derivations to Cachix
#   ./assemble-final.sh --board dedede --rootfs full --push-to-cachix

set -Eeuo pipefail

# ============================================================================
# === Functions ===
# ============================================================================

# === CI Detection ===
is_ci() {
	[ "${CI:-}" = "true" ] ||
		[ -n "${GITHUB_ACTIONS:-}" ] ||
		[ -n "${GITLAB_CI:-}" ] ||
		[ -n "${JENKINS_HOME:-}" ]
}

# === Logging Functions ===
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'

log_step() { printf "${ANSI_BOLD}${ANSI_BLUE}[%s] %s${ANSI_CLEAR}\n" "$1" "$2"; }
log_info() { printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"; }
log_warn() { printf "${ANSI_YELLOW}  ! %s${ANSI_CLEAR}\n" "$1"; }
log_error() { printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"; }
log_success() { printf "${ANSI_GREEN}  ✓ %s${ANSI_CLEAR}\n" "$1"; }

# === Safe Execution Wrapper ===
safe_exec() {
	if [ "${DRY_RUN:-0}" -eq 1 ]; then
		log_info "[DRY-RUN] Would execute: $*"
	else
		"$@"
	fi
}

# === Retry Logic ===
retry_command() {
	local max_attempts="${1:-3}"
	local wait_time="${2:-5}"
	shift 2
	local attempt=1

	while [ $attempt -le $max_attempts ]; do
		log_info "Attempt $attempt/$max_attempts: $*"
		if "$@"; then
			return 0
		fi

		local exit_code=$?
		if [ $attempt -lt $max_attempts ]; then
			log_warn "Command failed with exit code $exit_code, retrying in ${wait_time}s..."
			sleep "$wait_time"
		else
			log_error "Command failed after $max_attempts attempts"
			return $exit_code
		fi

		((attempt++))
	done
}

# === Loop Device Cleanup ===
cleanup_loop_devices() {
	log_info "Cleaning up loop devices..."

	while read -r dev; do
		[ -n "$dev" ] || continue
		log_info "Detaching $dev..."
		safe_exec sudo losetup -d "$dev" 2>/dev/null || safe_exec sudo losetup -d "$dev" -f 2>/dev/null || true
	done < <(losetup -j "${WORKDIR:-}" 2>/dev/null | cut -d: -f1)

	for dev in "${LOOPDEV:-}" "${LOOPROOT:-}"; do
		if [ -n "$dev" ] && losetup "$dev" &>/dev/null; then
			sudo losetup -d "$dev" 2>/dev/null || true
		fi
	done
}

# === General Cleanup ===
cleanup() {
	log_info "Cleanup: unmounting and detaching loop devices..."
	set +e

	for mnt in "${WORKDIR:-}/mnt_rootfs" "${WORKDIR:-}/mnt_bootloader" \
		"${WORKDIR:-}/mnt_src_rootfs" "${WORKDIR:-}/inspect_rootfs" \
		"${WORKDIR:-}/mnt_vendor"; do
		if mountpoint -q "$mnt" 2>/dev/null; then
			log_info "Unmounting $mnt..."
			for i in {1..3}; do
				safe_exec sudo umount "$mnt" 2>/dev/null && break
				sleep 0.5
				[ $i -eq 3 ] && safe_exec sudo umount -l "$mnt" 2>/dev/null
			done
		fi
	done

	sync
	sleep 1

	cleanup_loop_devices

	set -e
}

# === Interrupt Handler ===
handle_interrupt() {
	echo
	log_warn "Keyboard interrupt detected (Ctrl+C)"
	log_warn "Cleaning up in-progress mounts and loop devices..."

	trap - INT

	cleanup

	log_error "Assembly interrupted by user."
	exit 130
}

# === Error Handler ===
handle_error() {
	local exit_code=$?
	local step="${1:-unknown}"

	log_error "Build failed at step $step with exit code $exit_code"

	case "$step" in
	"1/15")
		log_error "Troubleshooting:"
		log_error "  1. Check Nix daemon: systemctl status nix-daemon"
		log_error "  2. Clear build cache: nix-collect-garbage -d"
		log_error "  3. Verify board exists: ls manifests/${BOARD:-<not set>}-manifest.nix"
		;;
	"2/15")
		log_error "Driver harvest failed. Check:"
		log_error "  1. Shim file exists: ${SHIM_BIN:-<not yet resolved>}"
		log_error "  2. Recovery image valid (if used)"
		;;
	"12/15")
		log_error "Partition formatting failed. Possible causes:"
		log_error "  1. Loop device issues: sudo losetup -D"
		log_error "  2. Insufficient permissions"
		log_error "  3. Corrupted image file"
		;;
	"13/15")
		log_error "Bootloader population failed. Check:"
		log_error "  1. Patched initramfs exists: ${PATCHED_INITRAMFS:-<not yet resolved>}"
		log_error "  2. Bootloader partition mounted: ${LOOPDEV:-<not set>}p3"
		log_error "  3. Sufficient disk space"
		;;
	"14/15")
		log_error "Rootfs population failed. Check:"
		log_error "  1. Raw rootfs image exists: ${WORKDIR:-<not set>}/rootfs.img"
		log_error "  2. Target partition mounted: ${LOOPDEV:-<not set>}p${ROOTFS_PARTITION_INDEX:-5}"
		log_error "  3. User configuration valid"
		;;
	"15/15")
		log_error "Driver handling failed. Check:"
		log_error "  1. Harvested drivers exist: ${HARVEST_OUT:-<not set>}"
		log_error "  2. DRIVERS_MODE value: ${DRIVERS_MODE:-<not set>}"
		log_error "  3. Partition permissions"
		;;
	esac

	exit $exit_code
}

# === Cachix Configuration Verification ===
verify_cachix_config() {
	log_step "Pre-check" "Verifying Cachix configuration"

	if nix config show 2>/dev/null | grep -q "shimboot-systemd-nixos.cachix.org"; then
		log_info "✓ Cachix configured in Nix settings"
	else
		log_warn "Cachix not found in Nix settings; builds may not use cache"
		log_warn "This is normal if using flake-based config"
	fi

	if command -v curl >/dev/null 2>&1; then
		if curl -sf "${CACHIX_CACHE:-shimboot-systemd-nixos}.cachix.org/nix-cache-info" >/dev/null 2>&1; then
			log_info "✓ Cachix endpoint reachable"
		else
			log_warn "Cannot reach Cachix endpoint; falling back to local builds"
		fi
	fi

	log_info "Active substituters:"
	nix config show 2>/dev/null | grep "^substituters" | sed 's/^/    /' || true
}

# === Dry-Run Plan Display ===
show_dry_run() {
	local raw_rootfs_attr="raw-rootfs"
	[ "${ROOTFS_FLAVOR:-}" = "minimal" ] && raw_rootfs_attr="raw-rootfs-minimal"

	log_step "Dry Run" "Execution plan for shimboot image assembly"
	echo
	log_info "Board:              ${BOARD:-<not set>}"
	log_info "Rootfs flavor:      ${ROOTFS_FLAVOR:-full} (attr: .#${raw_rootfs_attr})"
	log_info "Drivers mode:       ${DRIVERS_MODE:-vendor}"
	log_info "Upstream firmware:  ${FIRMWARE_UPSTREAM:-1}"
	log_info "Inspect after:      ${INSPECT_AFTER:-no}"
	log_info "Push to Cachix:     ${PUSH_TO_CACHIX:-0}"
	log_info "Cleanup rootfs:     ${CLEANUP_ROOTFS:-0}"
	echo
	log_step "1/15" "nix build .#extracted-kernel-${BOARD}"
	log_step "1/15" "nix build .#initramfs-patching-${BOARD}"
	log_step "1/15" "nix build .#${raw_rootfs_attr}"
	log_step "1/15" "nix build .#chromeos-shim-${BOARD}"
	log_step "1/15" "nix build .#chromeos-recovery-${BOARD}"
	log_step "2/15" "harvest-drivers.sh --shim <shim> [--recovery <recovery>] --out work/${BOARD}/harvested"
	[ "${FIRMWARE_UPSTREAM:-1}" != "0" ] &&
		log_step "3/15" "git clone chromiumos/third_party/linux-firmware → merge into harvested firmware"
	log_step "4/15" "Prune unused firmware files"
	log_step "5/15" "Calculate vendor partition size"
	log_step "6/15" "Copy raw rootfs image to work/${BOARD}/rootfs.img"
	log_step "7/15" "nix-store --optimise on raw rootfs"
	log_step "8/15" "Calculate rootfs content size + partition sizing"
	log_step "9/15" "fallocate shimboot.img"
	log_step "10/15" "parted: GPT partition table (STATE, KERNEL, BOOT, ${DRIVERS_MODE:+VENDOR, }ROOTFS)"
	log_step "11/15" "losetup + cgpt boot flags on p2"
	log_step "12/15" "mkfs.ext4/ext2, dd kernel"
	log_step "13/15" "Populate bootloader (p3) with patched initramfs"
	log_step "14/15" "Populate rootfs (p${ROOTFS_PARTITION_INDEX:-5}) from raw image + git clone nixos-config"
	log_step "15/15" "Driver handling: ${DRIVERS_MODE:-vendor}"
	[ "${PUSH_TO_CACHIX:-0}" -eq 1 ] &&
		log_step "Cachix" "push-to-cachix.sh --board ${BOARD} --rootfs ${ROOTFS_FLAVOR} --drivers ${DRIVERS_MODE}"
	[ "${CLEANUP_ROOTFS:-0}" -eq 1 ] &&
		log_step "Cleanup" "cleanup-shimboot-rootfs.sh --keep ${CLEANUP_KEEP:-3}"
	echo
	log_info "Output: work/${BOARD}/shimboot.img"
	log_success "Dry run complete. Remove --dry-run to execute."
}

# === Driver Population Functions ===
populate_vendor() {
	if [ ! -b "${LOOPDEV:-}p4" ]; then
		log_error "Vendor partition p4 not found on ${LOOPDEV:-}"
		handle_error "${CURRENT_STEP:-15/15}"
	fi

	log_step "15/15" "Populate vendor partition (p4) with harvested drivers (/lib/modules, /lib/firmware)"
	safe_exec sudo mkdir -p "${WORKDIR:-}/mnt_vendor"
	safe_exec sudo mount "${LOOPDEV:-}p4" "${WORKDIR:-}/mnt_vendor"
	safe_exec sudo mkdir -p "${WORKDIR:-}/mnt_vendor/lib/modules" "${WORKDIR:-}/mnt_vendor/lib/firmware"

	if [ -d "${HARVEST_OUT:-}/lib/modules" ]; then
		log_info "Copying modules to vendor..."
		safe_exec sudo cp -a "${HARVEST_OUT}/lib/modules/." "${WORKDIR:-}/mnt_vendor/lib/modules/"
	else
		log_warn "No harvested lib/modules; nothing to place into vendor partition"
	fi

	if [ -d "${HARVEST_OUT:-}/lib/firmware" ]; then
		log_info "Copying firmware to vendor..."
		safe_exec sudo cp -a "${HARVEST_OUT}/lib/firmware/." "${WORKDIR:-}/mnt_vendor/lib/firmware/"
	else
		log_warn "No harvested lib/firmware; nothing to place into vendor partition"
	fi

	safe_exec sudo sync
	safe_exec sudo umount "${WORKDIR:-}/mnt_vendor"
}

inject_drivers() {
	log_step "15/15" "Inject drivers into rootfs (p${ROOTFS_PARTITION_INDEX:-5}) (/lib/modules, /lib/firmware, modprobe.d)"
	if [ -d "${HARVEST_OUT:-}/lib/modules" ]; then
		safe_exec sudo rm -rf "${WORKDIR:-}/mnt_rootfs/lib/modules"
		safe_exec sudo mkdir -p "${WORKDIR:-}/mnt_rootfs/lib"
		safe_exec sudo cp -a "${HARVEST_OUT}/lib/modules" "${WORKDIR:-}/mnt_rootfs/lib/modules"
	else
		log_warn "No harvested lib/modules; skipping module injection"
	fi
	if [ -d "${HARVEST_OUT:-}/lib/firmware" ]; then
		safe_exec sudo mkdir -p "${WORKDIR:-}/mnt_rootfs/lib/firmware"
		safe_exec sudo cp -a "${HARVEST_OUT}/lib/firmware/." "${WORKDIR:-}/mnt_rootfs/lib/firmware/"
	else
		log_warn "No harvested lib/firmware; skipping firmware injection"
	fi
	if [ -d "${HARVEST_OUT:-}/modprobe.d" ]; then
		safe_exec sudo mkdir -p "${WORKDIR:-}/mnt_rootfs/lib/modprobe.d" "${WORKDIR:-}/mnt_rootfs/etc/modprobe.d"
		safe_exec sudo cp -a "${HARVEST_OUT}/modprobe.d/." "${WORKDIR:-}/mnt_rootfs/lib/modprobe.d/" 2>/dev/null || true
		safe_exec sudo cp -a "${HARVEST_OUT}/modprobe.d/." "${WORKDIR:-}/mnt_rootfs/etc/modprobe.d/" 2>/dev/null || true
	fi
}

# === Help Display ===
show_help() {
	cat <<'HELPTEXT'
Usage: ./assemble-final.sh [OPTIONS]

Build and assemble a shimboot image with Nix outputs, drivers, and partitioning.

Options:
  --board BOARD            Target board (dedede, octopus, etc.) [default: dedede]
  --rootfs FLAVOR          Rootfs variant: full, minimal [interactive if omitted]
  --drivers MODE           Driver placement: vendor, inject, both, none [default: vendor]
  --firmware-upstream      Enable upstream firmware [default]
  --no-firmware-upstream   Disable upstream firmware
  --inspect                Inspect final image after build
  --dry-run                Show full execution plan without building or modifying anything
  --prewarm-cache          Attempt to fetch from Cachix before building
  --push-to-cachix         Push Nix derivations to Cachix after build
  --cleanup-rootfs         Prune older shimboot rootfs generations
  --cleanup-keep N        Keep last N generations [default: 3]
  --cleanup-no-dry-run     Actually delete in cleanup (default is dry-run)
  -h, --help               Show this help and exit

Environment variables:
  BOARD                    Same as --board
  CACHIX_AUTH_TOKEN        Authenticate with Cachix for push
  SKIP_RECOVERY            Set to 1 to skip recovery image
  NIXPKGS_ALLOW_UNFREE     Allow unfree packages [default: 1]

Examples:
  ./assemble-final.sh --board dedede --rootfs full
  ./assemble-final.sh --board dedede --rootfs minimal --drivers vendor
  ./assemble-final.sh --board dedede --rootfs full --dry-run
HELPTEXT
	exit 0
}

# ============================================================================
# === Config Defaults ===
# ============================================================================

SYSTEM="x86_64-linux"
BOARD="${BOARD:-}"
BOARD_EXPLICITLY_SET="${BOARD_EXPLICITLY_SET:-}"
ROOTFS_NAME="${ROOTFS_NAME:-nixos}"
ROOTFS_FLAVOR="${ROOTFS_FLAVOR:-}"
DRIVERS_MODE="${DRIVERS_MODE:-}"
INSPECT_AFTER="${INSPECT_AFTER:-}"
DRY_RUN="${DRY_RUN:-0}"
FIRMWARE_UPSTREAM="${FIRMWARE_UPSTREAM:-1}"
FIRMWARE_UPSTREAM_SET="${FIRMWARE_UPSTREAM_SET:-}"
CLEANUP_ROOTFS="${CLEANUP_ROOTFS:-0}"
CLEANUP_NO_DRY_RUN="${CLEANUP_NO_DRY_RUN:-0}"
CLEANUP_KEEP="${CLEANUP_KEEP:-}"
PREWARM_CACHE="${PREWARM_CACHE:-0}"
PUSH_TO_CACHIX="${PUSH_TO_CACHIX:-0}"
ONBOARDING_DONE="${ONBOARDING_DONE:-0}"

CACHIX_CACHE="shimboot-systemd-nixos"
CACHIX_PUBKEY="shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
export CACHIX_CACHE CACHIX_PUBKEY NIXPKGS_ALLOW_UNFREE="${NIXPKGS_ALLOW_UNFREE:-1}"

# === Nix Build Flags Configuration ===
if is_ci; then
	NIX_BUILD_FLAGS=(
		--impure
		--accept-flake-config
		--max-jobs auto
		--cores 0
		--log-lines 100
	)
else
	NIX_BUILD_FLAGS=(
		--impure
		--accept-flake-config
		--keep-going
		--fallback
	)
fi

# ============================================================================
# === Arg Parsing ===
# ============================================================================

while [ $# -gt 0 ]; do
	case "${1:-}" in
	-h | --help) show_help ;;
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
		FIRMWARE_UPSTREAM_SET=1
		shift
		;;
	--no-firmware-upstream)
		FIRMWARE_UPSTREAM="0"
		FIRMWARE_UPSTREAM_SET=1
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
	--cleanup-no-dry-run | --no-dry-run)
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
		log_error "Unknown option: ${1:-}"
		log_error "Run with --help for usage."
		exit 1
		;;
	esac
done

# ============================================================================
# === Interactive Onboarding ===
# ============================================================================

if [ -z "$BOARD_EXPLICITLY_SET" ] && [ "${ONBOARDING_DONE:-0}" -eq 0 ]; then
	if [ -t 0 ]; then
		echo
		read -rp "[assemble-final] Target board [default: dedede]: " board_choice
		BOARD="${board_choice:-dedede}"
	else
		log_warn "No --board specified; defaulting to 'dedede'."
		BOARD="dedede"
	fi
fi
BOARD="${BOARD:-dedede}"
if [ -z "$BOARD" ]; then
	log_error "Board name cannot be empty; use --board <name>."
	exit 1
fi

if [ -z "${ROOTFS_FLAVOR:-}" ] && [ -t 0 ] && [ "${ONBOARDING_DONE:-0}" -eq 0 ]; then
	echo
	echo "[assemble-final] Select rootfs flavor to build:"
	echo "  1) full     (recommended) → complete desktop with Home Manager, Rose Pine theme, and user applications (~16-20GB)"
	echo "  2) minimal  (lightweight) → base system with LightDM + Hyprland, network, and shell utilities (~6-8GB)"
	read -rp "Enter choice [1/2, default=1]: " choice
	case "${choice:-1}" in
	2) ROOTFS_FLAVOR="minimal" ;;
	*) ROOTFS_FLAVOR="full" ;;
	esac
else
	ROOTFS_FLAVOR="${ROOTFS_FLAVOR:-full}"
fi

if [ "${ROOTFS_FLAVOR}" != "full" ] && [ "${ROOTFS_FLAVOR}" != "minimal" ]; then
	log_error "Invalid --rootfs value: '${ROOTFS_FLAVOR}'. Use 'full' or 'minimal'."
	exit 1
fi

if [ -z "${DRIVERS_MODE:-}" ] && [ -t 0 ] && [ "${ONBOARDING_DONE:-0}" -eq 0 ]; then
	echo
	echo "[assemble-final] Select driver placement mode:"
	echo "  1) vendor  (default) → separate vendor partition, mounted at boot"
	echo "  2) inject            → copy drivers directly into rootfs"
	echo "  3) both              → vendor partition AND inject (redundant but safe)"
	echo "  4) none              → skip driver handling entirely"
	read -rp "Enter choice [1-4, default=1]: " drv_choice
	case "${drv_choice:-1}" in
	2) DRIVERS_MODE="inject" ;;
	3) DRIVERS_MODE="both" ;;
	4) DRIVERS_MODE="none" ;;
	*) DRIVERS_MODE="vendor" ;;
	esac
fi
DRIVERS_MODE="${DRIVERS_MODE:-vendor}"

if [ -z "$FIRMWARE_UPSTREAM_SET" ] && [ -t 0 ] && [ "${ONBOARDING_DONE:-0}" -eq 0 ]; then
	read -rp "[assemble-final] Include upstream ChromiumOS linux-firmware? [Y/n]: " fw_choice
	case "${fw_choice:-y}" in
	[Nn]*) FIRMWARE_UPSTREAM="0" ;;
	esac
fi

if [ -z "$INSPECT_AFTER" ] && [ -t 0 ] && [ "${ONBOARDING_DONE:-0}" -eq 0 ]; then
	read -rp "[assemble-final] Inspect final image after build? [y/N]: " inspect_choice
	case "${inspect_choice:-n}" in
	[Yy]*) INSPECT_AFTER="--inspect" ;;
	esac
fi

ONBOARDING_DONE=1

# ============================================================================
# === Sudo Elevation ===
# ============================================================================

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	if [ "$DRY_RUN" -eq 1 ]; then
		log_info "Dry-run mode: skipping sudo elevation"
	else
		echo "[assemble-final] Re-executing with sudo -H..."
		echo "[assemble-final] Please enter your sudo password when prompted..."
		SUDO_ENV=()
		for var in BOARD BOARD_EXPLICITLY_SET ROOTFS_FLAVOR DRIVERS_MODE \
			FIRMWARE_UPSTREAM FIRMWARE_UPSTREAM_SET INSPECT_AFTER DRY_RUN \
			CLEANUP_ROOTFS CLEANUP_NO_DRY_RUN \
			CLEANUP_KEEP PREWARM_CACHE PUSH_TO_CACHIX CACHIX_AUTH_TOKEN \
			ONBOARDING_DONE ROOTFS_NAME; do
			if [ -n "${!var:-}" ]; then SUDO_ENV+=("$var=${!var}"); fi
		done
		exec sudo -E -H env "${SUDO_ENV[@]}" "$0"
	fi
fi

# ============================================================================
# === Execution ===
# ============================================================================

# Set up error traps
trap 'handle_error "${CURRENT_STEP:-unknown}"' ERR
trap cleanup EXIT TERM
trap handle_interrupt INT

# Configure Cachix
if command -v cachix >/dev/null 2>&1; then
	log_info "Using Cachix cache: ${CACHIX_CACHE}"

	if [ -n "${CACHIX_AUTH_TOKEN:-}" ]; then
		cachix authtoken "$CACHIX_AUTH_TOKEN" 2>/dev/null || true
	fi

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

# Handle dry-run mode
if [ "$DRY_RUN" -eq 1 ]; then
	show_dry_run
	exit 0
fi

# Build raw-rootfs attribute name based on flavor
RAW_ROOTFS_ATTR="raw-rootfs"
if [ "${ROOTFS_FLAVOR}" = "minimal" ]; then
	RAW_ROOTFS_ATTR="raw-rootfs-minimal"
fi

log_info "Rootfs flavor: ${ROOTFS_FLAVOR} (attr: .#${RAW_ROOTFS_ATTR})"
log_info "Board: ${BOARD}"
log_info "Drivers mode: ${DRIVERS_MODE} (vendor|inject|none)"
log_info "Upstream firmware: ${FIRMWARE_UPSTREAM} (0=disabled, 1=enabled)"
log_info "Push to Cachix: ${PUSH_TO_CACHIX} (0=disabled, 1=enabled, derivations only)"

# === Setup Workspace Path ===
if [ -d "/nix" ] && mountpoint -q /nix 2>/dev/null; then
	NIX_AVAIL_GB=$(df -BG /nix | awk 'NR==2 {print $4}' | sed 's/G//')
	if [ "${NIX_AVAIL_GB:-0}" -gt 50 ]; then
		WORKDIR="/nix/work/${BOARD}"
		log_info "CI mode detected: using ${WORKDIR} (${NIX_AVAIL_GB}GB available)"
	else
		WORKDIR="$(pwd)/work/${BOARD}"
	fi
else
	WORKDIR="$(pwd)/work/${BOARD}"
fi

IMAGE="$WORKDIR/shimboot.img"
LOOPDEV=""
LOOPROOT=""

# Verify Cachix configuration before building
verify_cachix_config

# Prewarm cache if requested
if [ "$PREWARM_CACHE" -eq 1 ]; then
	log_step "Pre-warm" "Attempting to fetch from Cachix"

	nix build --dry-run \
		.#extracted-kernel-${BOARD} \
		.#initramfs-patching-${BOARD} \
		.#${RAW_ROOTFS_ATTR} \
		2>&1 | grep "will be fetched" || log_info "Nothing to fetch"
fi

# === Step 1: Build Nix outputs (parallel) ===
CURRENT_STEP="1/15"
log_step "$CURRENT_STEP" "Building Nix outputs (parallel)"

nix build "${NIX_BUILD_FLAGS[@]}" .#extracted-kernel-${BOARD} &
KERNEL_PID=$!
nix build "${NIX_BUILD_FLAGS[@]}" .#initramfs-patching-${BOARD} &
INITRAMFS_PID=$!
nix build "${NIX_BUILD_FLAGS[@]}" .#${RAW_ROOTFS_ATTR} &
ROOTFS_PID=$!

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

ORIGINAL_KERNEL="$(nix build --impure --accept-flake-config ".#extracted-kernel-${BOARD}" --print-out-paths)/p2.bin"
PATCHED_INITRAMFS="$(nix build --impure --accept-flake-config ".#initramfs-patching-${BOARD}" --print-out-paths)/patched-initramfs"
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

if [ ! -f "$ORIGINAL_KERNEL" ]; then
	log_error "Kernel binary build failed or missing: $ORIGINAL_KERNEL"
	handle_error "$CURRENT_STEP"
fi

log_info "Original kernel p2: $ORIGINAL_KERNEL"
log_info "Patched initramfs dir: $PATCHED_INITRAMFS"
log_info "Raw rootfs: $RAW_ROOTFS_IMG"

SHIM_BIN="$(nix build "${NIX_BUILD_FLAGS[@]}" .#chromeos-shim-${BOARD} --print-out-paths)"
RECOVERY_BIN_PATH="$(nix build "${NIX_BUILD_FLAGS[@]}" .#chromeos-recovery-${BOARD} --print-out-paths)"
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

# === Step 2: Harvest ChromeOS drivers ===
HARVEST_OUT="$WORKDIR/harvested"
mkdir -p "$HARVEST_OUT"
CURRENT_STEP="2/15"
log_step "$CURRENT_STEP" "Harvest ChromeOS drivers"
if [ -n "$RECOVERY_PATH" ]; then
	bash tools/harvest-drivers.sh --shim "$SHIM_BIN" --recovery "$RECOVERY_PATH" --out "$HARVEST_OUT" || {
		log_error "Driver harvest failed with recovery image"
		handle_error "$CURRENT_STEP"
	}
else
	bash tools/harvest-drivers.sh --shim "$SHIM_BIN" --out "$HARVEST_OUT" || {
		log_error "Driver harvest failed without recovery image"
		handle_error "$CURRENT_STEP"
	}
fi

# === Step 3: Augment firmware with upstream ===
if [ "${FIRMWARE_UPSTREAM:-1}" != "0" ]; then
	CURRENT_STEP="3/15"
	log_step "$CURRENT_STEP" "Augment firmware with upstream linux-firmware"
	log_info "Cloning upstream linux-firmware repository..."
	UPSTREAM_FW_DIR="$WORKDIR/linux-firmware.upstream"
	if [ ! -d "$UPSTREAM_FW_DIR" ]; then
		git clone --depth=1 https://chromium.googlesource.com/chromiumos/third_party/linux-firmware "$UPSTREAM_FW_DIR" || true
	fi
	log_info "Merging upstream firmware with harvested firmware..."
	mkdir -p "$HARVEST_OUT/lib/firmware"
	sudo cp -a "$UPSTREAM_FW_DIR/." "$HARVEST_OUT/lib/firmware/" 2>/dev/null || true
	log_info "Upstream firmware augmentation complete"
else
	log_info "Upstream firmware disabled, using only harvested firmware"
fi

# === Step 4: Prune unused firmware files ===
if [ -d "$HARVEST_OUT/lib/firmware" ]; then
	CURRENT_STEP="4/15"
	log_step "$CURRENT_STEP" "Prune unused firmware files"
	SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	if [ -f "$SCRIPT_DIR/tools/harvest-drivers.sh" ]; then
		bash -c "source '$SCRIPT_DIR/tools/harvest-drivers.sh' && prune_unused_firmware '$HARVEST_OUT/lib/firmware'"
	else
		log_warn "harvest-drivers.sh not found; skipping firmware pruning"
	fi
fi

# === Step 5: Calculate vendor partition size ===
CURRENT_STEP="5/15"
log_step "$CURRENT_STEP" "Calculate vendor partition size after firmware merge"
VENDOR_SRC_SIZE_MB=0
if [ -d "$HARVEST_OUT/lib/modules" ]; then
	VENDOR_SRC_SIZE_MB=$((VENDOR_SRC_SIZE_MB + $(sudo du -sm "$HARVEST_OUT/lib/modules" | cut -f1)))
fi
if [ -d "$HARVEST_OUT/lib/firmware" ]; then
	VENDOR_SRC_SIZE_MB=$((VENDOR_SRC_SIZE_MB + $(sudo du -sm "$HARVEST_OUT/lib/firmware" | cut -f1)))
fi

VENDOR_PART_SIZE=$(((VENDOR_SRC_SIZE_MB * 115 / 100) + 20))
log_info "Vendor partition size (post-firmware): ${VENDOR_PART_SIZE} MB"

# === Step 6: Copy raw rootfs image ===
CURRENT_STEP="6/15"
log_step "$CURRENT_STEP" "Copy raw rootfs image"
if [ ! -f "$RAW_ROOTFS_IMG" ]; then
	log_error "Raw rootfs image is not a file: $RAW_ROOTFS_IMG"
	handle_error "$CURRENT_STEP"
fi
pv "$RAW_ROOTFS_IMG" >"$WORKDIR/rootfs.img"

# === Step 7: Optimize Nix store in raw rootfs ===
CURRENT_STEP="7/15"
log_step "$CURRENT_STEP" "Optimize Nix store in raw rootfs"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img") || {
	log_error "Failed to setup loop device for rootfs optimization"
	handle_error "$CURRENT_STEP"
}
safe_exec sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs" || {
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
CURRENT_STEP="8/15"
log_step "$CURRENT_STEP" "Calculate rootfs size"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
safe_exec sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
ROOTFS_SIZE_MB=$(sudo du -sm "$WORKDIR/mnt_src_rootfs" | cut -f1)
log_info "Rootfs content size: ${ROOTFS_SIZE_MB} MB"
safe_exec sudo umount "$WORKDIR/mnt_src_rootfs"
safe_exec sudo losetup -d "$LOOPROOT"
LOOPROOT=""

ROOTFS_PART_SIZE=$(((ROOTFS_SIZE_MB * 110 / 100) + 100))
log_info "Rootfs partition size: ${ROOTFS_PART_SIZE} MB (with safety margin)"

VENDOR_START_MB=54
VENDOR_END_MB=$((VENDOR_START_MB + VENDOR_PART_SIZE))
TOTAL_SIZE_MB=$((1 + 32 + 20 + VENDOR_PART_SIZE + ROOTFS_PART_SIZE))
log_info "Vendor partition size: ${VENDOR_PART_SIZE} MB"
log_info "Rootfs partition size: ${ROOTFS_PART_SIZE} MB (initial, expandable)"
log_info "Total image size: ${TOTAL_SIZE_MB} MB"

# === Step 9: Create empty image ===
CURRENT_STEP="9/15"
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
CURRENT_STEP="10/15"
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
CURRENT_STEP="11/15"
log_step "$CURRENT_STEP" "Setup loop device"
LOOPDEV=$(sudo losetup --show -fP "$IMAGE") || {
	log_error "Failed to setup loop device for $IMAGE"
	handle_error "$CURRENT_STEP"
}
log_info "Loop device: $LOOPDEV"

if ! command -v cgpt >/dev/null 2>&1; then
	log_info "cgpt not found in PATH, searching in Nix store..."
	CGPT_PATH=$(find /nix/store -name "cgpt" -type f -executable 2>/dev/null | grep vboot_reference | head -n1)
	if [ -n "$CGPT_PATH" ]; then
		log_info "Found cgpt at: $CGPT_PATH"
		export PATH="$(dirname "$CGPT_PATH"):${PATH}"
	else
		log_error "cgpt not found in Nix store. Please ensure vboot_reference is installed."
		log_error "Try running: nix develop"
		handle_error "$CURRENT_STEP"
	fi
fi

log_info "Setting ChromeOS boot flags on KERNEL partition..."
safe_exec sudo cgpt add -i 2 -S 1 -T 5 -P 10 "$LOOPDEV" || {
	log_error "Failed to set ChromeOS boot flags"
	handle_error "$CURRENT_STEP"
}

# === Step 12: Format partitions ===
CURRENT_STEP="12/15"
log_step "$CURRENT_STEP" "Format partitions"
MKFS_EXT4_OPTS=(-F -O "^orphan_file,^metadata_csum_seed")
safe_exec sudo mkfs.ext4 -q "${MKFS_EXT4_OPTS[@]}" "${LOOPDEV}p1"
safe_exec sudo dd if="$ORIGINAL_KERNEL" of="${LOOPDEV}p2" bs=1M conv=fsync status=progress
safe_exec sudo mkfs.ext2 -F -q "${LOOPDEV}p3"

if [ "$HAS_VENDOR_PARTITION" -eq 1 ]; then
	safe_exec sudo mkfs.ext4 -q -O ^has_journal,^orphan_file,^metadata_csum_seed \
		-L "shimboot_vendor" "${LOOPDEV}p4"
	safe_exec sudo mkfs.ext4 -q -L "$ROOTFS_NAME" "${MKFS_EXT4_OPTS[@]}" \
		"${LOOPDEV}p${ROOTFS_PARTITION_INDEX}"
else
	safe_exec sudo mkfs.ext4 -q -L "$ROOTFS_NAME" "${MKFS_EXT4_OPTS[@]}" \
		"${LOOPDEV}p${ROOTFS_PARTITION_INDEX}"
fi

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
CURRENT_STEP="13/15"
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
CURRENT_STEP="14/15"
log_step "$CURRENT_STEP" "Populate rootfs partition (now p${ROOTFS_PARTITION_INDEX})"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
safe_exec sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
safe_exec sudo mount "${LOOPDEV}p${ROOTFS_PARTITION_INDEX}" "$WORKDIR/mnt_rootfs"
total_bytes=$(sudo du -sb "$WORKDIR/mnt_src_rootfs" | cut -f1)
(cd "$WORKDIR/mnt_src_rootfs" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_rootfs" && sudo tar xf -)

USERNAME="$(nix eval "${NIX_BUILD_FLAGS[@]}" --expr "(import ./shimboot_config/user-config.nix {}).user.username" --json | jq -r .)"
log_info "Using username from userConfig: $USERNAME"

log_info "Cloning nixos-config repository into rootfs..."
NIXOS_CONFIG_DEST="$WORKDIR/mnt_rootfs/home/${USERNAME}/nixos-config"

if command -v git >/dev/null 2>&1 && [ -d .git ]; then
	GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
	GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
	GIT_STATUS=$(git status --porcelain | wc -l 2>/dev/null || echo "0")
	BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "unknown")

	if [ -d "$NIXOS_CONFIG_DEST" ]; then
		log_info "Removing existing nixos-config directory"
		safe_exec sudo rm -rf "$NIXOS_CONFIG_DEST"
	fi

	log_info "Cloning nixos-config repository..."
	safe_exec sudo git clone --no-local "$(pwd)" "$NIXOS_CONFIG_DEST"
	ACTUAL_REMOTE=$(git remote get-url origin 2>/dev/null || echo "https://github.com/PopCat19/nixos-shimboot.git")
	safe_exec sudo git -C "$NIXOS_CONFIG_DEST" remote set-url origin "$ACTUAL_REMOTE"

	if [ "$GIT_BRANCH" != "unknown" ]; then
		log_info "Switching to branch: $GIT_BRANCH"
		safe_exec sudo git -C "$NIXOS_CONFIG_DEST" checkout "$GIT_BRANCH" || log_warn "Failed to checkout branch $GIT_BRANCH"
	fi

	safe_exec sudo chown -R 1000:1000 "$NIXOS_CONFIG_DEST"

	sudo tee "$NIXOS_CONFIG_DEST/.shimboot_branch" >/dev/null <<EOF
# Shimboot build information
BUILD_DATE=$BUILD_DATE
GIT_BRANCH=$GIT_BRANCH
GIT_COMMIT=$GIT_COMMIT
GIT_CHANGES=$GIT_STATUS
GIT_REMOTE=$GIT_REMOTE
EOF

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

safe_exec sudo umount "$WORKDIR/mnt_src_rootfs"
safe_exec sudo losetup -d "$LOOPROOT"
LOOPROOT=""

# === Step 15: Handle driver placement strategy ===
CURRENT_STEP="15/15"
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

safe_exec sudo umount "$WORKDIR/mnt_rootfs"
safe_exec sudo losetup -d "$LOOPDEV"
LOOPDEV=""
log_info "✅ Final image created at: $IMAGE"

# === Optional cleanup of old shimboot rootfs generations ===
if [ "${CLEANUP_ROOTFS:-0}" -eq 1 ]; then
	CURRENT_STEP="Cleanup"
	log_step "$CURRENT_STEP" "Pruning older shimboot rootfs generations"
	CLEANUP_CMD=(sudo bash tools/cleanup-shimboot-rootfs.sh --results-dir "$(pwd)")
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
	log_step "Cachix" "Pushing Nix derivations to Cachix..."

	if [ -f "tools/push-to-cachix.sh" ]; then
		if command -v cachix >/dev/null 2>&1; then
			if is_ci && [ -z "${CACHIX_AUTH_TOKEN:-}" ]; then
				log_warn "CACHIX_AUTH_TOKEN not set in CI environment"
				log_warn "Set it to enable automatic pushing to Cachix"
			else
				log_info "Executing: ./tools/push-to-cachix.sh --board $BOARD --rootfs $ROOTFS_FLAVOR --drivers $DRIVERS_MODE"
				if bash tools/push-to-cachix.sh --board "$BOARD" --rootfs "$ROOTFS_FLAVOR" --drivers "$DRIVERS_MODE"; then
					log_success "Successfully pushed Nix derivations to Cachix"
				else
					log_error "Failed to push Nix derivations to Cachix"
					log_error "You can manually retry with:"
					log_error "  ./tools/push-to-cachix.sh --board $BOARD --rootfs $ROOTFS_FLAVOR --drivers $DRIVERS_MODE"
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
	log_info "To push Nix derivations to Cachix (shim, recovery, kernel, initramfs, rootfs, chunks), run:"
	log_info "  ./tools/push-to-cachix.sh --board $BOARD --rootfs $ROOTFS_FLAVOR --drivers $DRIVERS_MODE"
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
		log_info "Init found at /sbin/init → $(file -b "$WORKDIR/inspect_rootfs/sbin/init")"
	elif [ -f "$WORKDIR/inspect_rootfs/init" ]; then
		log_info "Init found at /init → $(file -b "$WORKDIR/inspect_rootfs/init")"
	else
		log_error "Init missing"
	fi
	safe_exec sudo umount "$WORKDIR/inspect_rootfs"

	safe_exec sudo losetup -d "$LOOPDEV"
fi
