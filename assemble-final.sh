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
#   --pull-cached-image    Pull pre-built image from Cachix instead of building
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
#   # Use cached image instead of building
#   ./assemble-final.sh --board dedede --rootfs full --pull-cached-image

set -Eeuo pipefail

# === Error Handling ===
handle_error() {
    local exit_code=$?
    local step="$1"
    
    log_error "Build failed at step $step with exit code $exit_code"
    
    case "$step" in
        "1/15")
            log_error "Troubleshooting:"
            log_error "  1. Check Nix daemon: systemctl status nix-daemon"
            log_error "  2. Clear build cache: nix-collect-garbage -d"
            log_error "  3. Verify board exists: ls manifests/${BOARD}-manifest.nix"
            ;;
        "2/15")
            log_error "Driver harvest failed. Check:"
            log_error "  1. Shim file exists: $SHIM_BIN"
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
            log_error "  1. Patched initramfs exists: $PATCHED_INITRAMFS"
            log_error "  2. Bootloader partition mounted: ${LOOPDEV}p3"
            log_error "  3. Sufficient disk space"
            ;;
        "14/15")
            log_error "Rootfs population failed. Check:"
            log_error "  1. Raw rootfs image exists: $WORKDIR/rootfs.img"
            log_error "  2. Target partition mounted: ${LOOPDEV}p5"
            log_error "  3. User configuration valid"
            ;;
        "15/15")
            log_error "Driver handling failed. Check:"
            log_error "  1. Harvested drivers exist: $HARVEST_OUT"
            log_error "  2. DRIVERS_MODE value: $DRIVERS_MODE"
            log_error "  3. Partition permissions"
            ;;
    esac
    
    exit $exit_code
}

# Set up error trap
trap 'handle_error "${CURRENT_STEP:-unknown}"' ERR

# Elevate to root so nix-daemon treats this client as trusted; required for substituters/trusted-public-keys
# Use -H to set HOME to /root to avoid "$HOME is not owned by you" warnings under sudo.
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "[assemble-final] Re-executing with sudo -H..."
	SUDO_ENV=()
	for var in BOARD BOARD_EXPLICITLY_SET CACHIX_AUTH_TOKEN; do
		if [ -n "${!var:-}" ]; then SUDO_ENV+=("$var=${!var}"); fi
	done
	exec sudo -E -H "${SUDO_ENV[@]}" "$0" "$@"
fi

# === CI Detection ===
is_ci() {
	[ "${CI:-}" = "true" ] || \
	[ -n "${GITHUB_ACTIONS:-}" ] || \
	[ -n "${GITLAB_CI:-}" ] || \
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

# Add after color definitions
show_progress() {
    local current="$1"
    local total="$2"
    local step_name="$3"
    local percent=$((current * 100 / total))
    
    printf "\r${ANSI_BLUE}Progress: [%-50s] %d%% (%d/%d) - %s${ANSI_CLEAR}" \
        "$(printf '#%.0s' $(seq 1 $((percent / 2))))" \
        "$percent" "$current" "$total" "$step_name"
    
    [ "$current" -eq "$total" ] && echo
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
        log_info "✓ Cachix configured in Nix settings"
    else
        log_warn "Cachix not found in Nix settings; builds may not use cache"
        log_warn "This is normal if using flake-based config"
    fi
    
    # Test Cachix connectivity
    if command -v curl >/dev/null 2>&1; then
        if curl -sf "https://${CACHIX_CACHE}.cachix.org/nix-cache-info" >/dev/null; then
            log_info "✓ Cachix endpoint reachable"
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

# === Config ===
SYSTEM="x86_64-linux"

# Detect if we're in CI with Nothing but Nix (large /nix mount)
if [ -d "/nix" ] && mountpoint -q /nix 2>/dev/null; then
    # Check if /nix has >50GB free (indicates CI environment)
    NIX_AVAIL_GB=$(df -BG /nix | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "${NIX_AVAIL_GB:-0}" -gt 50 ]; then
        WORKDIR="/nix/work"
        log_info "CI mode detected: using /nix/work (${NIX_AVAIL_GB}GB available)"
    else
        WORKDIR="$(pwd)/work"
    fi
else
    WORKDIR="$(pwd)/work"
fi

IMAGE="$WORKDIR/shimboot.img"

# Initialize BOARD_EXPLICITLY_SET before CLI parsing
BOARD_EXPLICITLY_SET="${BOARD_EXPLICITLY_SET:-}"
BOARD="${BOARD:-}"  # Don't set default yet
ROOTFS_NAME="${ROOTFS_NAME:-nixos}"
ROOTFS_FLAVOR="${ROOTFS_FLAVOR:-}"
INSPECT_AFTER=""

# Dry run option
DRY_RUN=0

# Firmware options
FIRMWARE_UPSTREAM="${FIRMWARE_UPSTREAM:-1}"

# Cleanup options
CLEANUP_ROOTFS=0
CLEANUP_NO_DRY_RUN=0
CLEANUP_KEEP=""

# Cache options
PREWARM_CACHE=0
PULL_CACHED_IMAGE=0

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
		FIRMWARE_UPSTREAM="${2:-1}"
		shift 2
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
	--pull-cached-image)
		PULL_CACHED_IMAGE=1
		shift
		;;
	*)
		# Backward compat: if a single arg was passed previously as inspect flag
		if [ "${1:-}" = "--inspect" ]; then
			INSPECT_AFTER="--inspect"
		fi
		shift
		;;
	esac
done

# NOW set default board if not provided
if [ -z "$BOARD" ]; then
	BOARD="dedede"
fi

# Warn only if board wasn't explicitly provided
if [ -z "$BOARD_EXPLICITLY_SET" ]; then
    log_warn "No --board specified; defaulting to 'dedede'."
    log_warn "If this is unintended, rerun with --board <name>."
    sleep 1
fi

if [ -z "$BOARD" ]; then
    log_error "Board name cannot be empty; use --board <name>."
    exit 1
fi

# Interactive prompt if not provided, default to full
if [ -z "${ROOTFS_FLAVOR:-}" ]; then
	if [ -t 0 ]; then
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
		ROOTFS_FLAVOR="full"
	fi
fi

if [ "${ROOTFS_FLAVOR}" != "full" ] && [ "${ROOTFS_FLAVOR}" != "minimal" ]; then
	log_error "Invalid --rootfs value: '${ROOTFS_FLAVOR}'. Use 'full' or 'minimal'."
	exit 1
fi

RAW_ROOTFS_ATTR="raw-rootfs"
if [ "${ROOTFS_FLAVOR}" = "minimal" ]; then
	RAW_ROOTFS_ATTR="raw-rootfs-minimal"
fi

log_info "Rootfs flavor: ${ROOTFS_FLAVOR} (attr: .#${RAW_ROOTFS_ATTR})"
log_info "Board: ${BOARD}"
# Default drivers mode to 'vendor' unless overridden by --drivers or env
DRIVERS_MODE="${DRIVERS_MODE:-vendor}"
log_info "Drivers mode: ${DRIVERS_MODE} (vendor|inject|none)"
log_info "Upstream firmware: ${FIRMWARE_UPSTREAM} (0=disabled, 1=enabled)"
if [ "$DRY_RUN" -eq 1 ]; then
    log_warn "DRY RUN MODE: No destructive operations will be performed"
fi

# === Safe execution wrapper for destructive operations ===
safe_exec() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log_info "[DRY-RUN] Would execute: $*"
    else
        "$@"
    fi
}

# === Cleanup workspace ===
if [ -d "$WORKDIR" ]; then
	log_warn "Cleaning up old work directory..."
	safe_exec sudo rm -rf "$WORKDIR"
fi
mkdir -p "$WORKDIR" "$WORKDIR/mnt_src_rootfs" "$WORKDIR/mnt_bootloader" "$WORKDIR/mnt_rootfs"

# Add after workspace creation (before Step 1)
check_disk_space() {
    local required_gb="${1:-30}"
    local path="${2:-.}"
    local available_gb=$(df -BG "$path" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "${available_gb:-0}" -lt "$required_gb" ]; then
        log_error "Insufficient disk space: ${available_gb}GB available, ${required_gb}GB required"
        log_error "Free up space or use --workdir /path/to/larger/partition"
        exit 1
    fi
    log_info "Disk space check: ${available_gb}GB available (${required_gb}GB required)"
}

# Usage
check_disk_space 30 "$(dirname "$WORKDIR")"

# === Function: Check for cached image ===
check_cached_image() {
    local board="$1"
    local rootfs="$2"
    local drivers="$3"
    
    log_step "Cache" "Checking for pre-built image in Cachix"
    
    # Get git commit
    local git_commit="unknown"
    if command -v git >/dev/null 2>&1 && [[ -d .git ]]; then
        git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi
    
    # Compute config hash (same as push-to-cachix.sh)
    local config_hash
    config_hash=$(echo "${board}-${rootfs}-${drivers}-${git_commit}" | sha256sum | cut -d' ' -f1 | cut -c1-16)
    
    local manifest_name="shimboot-manifest-${config_hash}.json"
    local manifest_url="https://${CACHIX_CACHE}.cachix.org/${manifest_name}"
    
    log_info "Looking for manifest: $manifest_name"
    
    # Check if manifest exists
    if ! curl -sf "$manifest_url" -o "/tmp/${manifest_name}" 2>/dev/null; then
        log_warn "No cached image found for this configuration"
        return 1
    fi
    
    log_success "Found cached image manifest"
    
    # Parse manifest
    local filename
    filename=$(jq -r '.filename' "/tmp/${manifest_name}")
    
    if [[ -z "$filename" ]] || [[ "$filename" == "null" ]]; then
        log_error "Invalid manifest format"
        rm -f "/tmp/${manifest_name}"
        return 1
    fi
    
    # Download compressed image
    local image_url="https://${CACHIX_CACHE}.cachix.org/${filename}"
    log_info "Downloading: $filename"
    
    if ! curl -L --progress-bar "$image_url" -o "/tmp/${filename}"; then
        log_error "Failed to download cached image"
        rm -f "/tmp/${manifest_name}"
        return 1
    fi
    
    # Decompress
    log_info "Decompressing image..."
    if ! pv "/tmp/${filename}" | zstd -d > "$IMAGE"; then
        log_error "Failed to decompress image"
        rm -f "/tmp/${filename}" "/tmp/${manifest_name}"
        return 1
    fi
    
    # Cleanup
    rm -f "/tmp/${filename}" "/tmp/${manifest_name}"
    
    log_success "Successfully retrieved cached image: $IMAGE"
    return 0
}

START_STEP=0

# === Track loop devices for cleanup ===
LOOPDEV=""
LOOPROOT=""

cleanup_loop_devices() {
    log_info "Cleaning up loop devices..."
    
    # Find all loops associated with our work directory
    while read -r dev; do
        [ -n "$dev" ] || continue
        log_info "Detaching $dev..."
        safe_exec sudo losetup -d "$dev" 2>/dev/null || safe_exec sudo losetup -d "$dev" -f 2>/dev/null || true
    done < <(losetup -j "$WORKDIR" 2>/dev/null | cut -d: -f1)
    
    # Explicit cleanup of tracked devices
    for dev in "$LOOPDEV" "$LOOPROOT"; do
        if [ -n "$dev" ] && losetup "$dev" &>/dev/null; then
            safe_exec sudo losetup -d "$dev" 2>/dev/null || true
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
    			[ $i -eq 3 ] && safe_exec sudo umount -l "$mnt" 2>/dev/null
    		done
    	fi
    done
    
    sync
    sleep 1  # Give kernel time to settle
    
    cleanup_loop_devices
    
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
    exit 130   # 130 = 128 + SIGINT
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

# === Nix Build Flags Configuration ===
if is_ci; then
    NIX_BUILD_FLAGS=(
        --impure
        --accept-flake-config
        --max-jobs auto
        --cores 0  # Use all cores
        --log-lines 100  # Limit log spam in CI
    )
else
    NIX_BUILD_FLAGS=(
        --impure
        --accept-flake-config
        --keep-going  # Try to build as much as possible
        --fallback    # Fallback to local build if substituter fails
    )
fi


# Call before Step 1
verify_cachix_config

# Add before Step 1
if [ "$PREWARM_CACHE" -eq 1 ]; then
    log_step "Pre-warm" "Attempting to fetch from Cachix"
    
    # Try to substitute without building
    nix build --dry-run \
        .#extracted-kernel-${BOARD} \
        .#initramfs-patching-${BOARD} \
        .#${RAW_ROOTFS_ATTR} \
        2>&1 | grep "will be fetched" || log_info "Nothing to fetch"
fi

# === Check for cached image if requested ===
if [ "$PULL_CACHED_IMAGE" -eq 1 ]; then
    if check_cached_image "$BOARD" "$ROOTFS_FLAVOR" "$DRIVERS_MODE"; then
        log_success "Using cached image, skipping build"
        
        # Optionally inspect
        if [ "$INSPECT_AFTER" = "--inspect" ]; then
            CURRENT_STEP="Inspect"
            log_step "$CURRENT_STEP" "Partition table and init check"
            safe_exec sudo partx -o NR,START,END,SIZE,TYPE,NAME,UUID -g --show "$IMAGE"
            LOOPDEV=$(sudo losetup --show -fP "$IMAGE")
            mkdir -p "$WORKDIR/inspect_rootfs"
            safe_exec sudo mount "${LOOPDEV}p5" "$WORKDIR/inspect_rootfs"
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
        
        exit 0
    else
        log_warn "Cached image not found, proceeding with build"
    fi
fi

# === Step 1: Build Nix outputs (parallel) ===
if [ "$START_STEP" -le 1 ]; then
    CURRENT_STEP="1/15"
    log_step "$CURRENT_STEP" "Building Nix outputs (parallel)"

    # Build all in parallel, capture PIDs
    nix build "${NIX_BUILD_FLAGS[@]}" .#extracted-kernel-${BOARD} &
    KERNEL_PID=$!
    nix build "${NIX_BUILD_FLAGS[@]}" .#initramfs-patching-${BOARD} &
    INITRAMFS_PID=$!
    nix build "${NIX_BUILD_FLAGS[@]}" .#${RAW_ROOTFS_ATTR} &
    ROOTFS_PID=$!

    # Wait and check each
    wait $KERNEL_PID || { log_error "Kernel build failed"; handle_error "$CURRENT_STEP"; }
    wait $INITRAMFS_PID || { log_error "Initramfs build failed"; handle_error "$CURRENT_STEP"; }
    wait $ROOTFS_PID || { log_error "Rootfs build failed"; handle_error "$CURRENT_STEP"; }

    # Get paths (instant since already built)
    ORIGINAL_KERNEL="$(nix build --impure --accept-flake-config ".#extracted-kernel-${BOARD}" --print-out-paths)/p2.bin"
    PATCHED_INITRAMFS="$(nix build --impure --accept-flake-config ".#initramfs-patching-${BOARD}" --print-out-paths)/patched-initramfs"
    RAW_ROOTFS_IMG="$(nix build --impure --accept-flake-config ".#${RAW_ROOTFS_ATTR}" --print-out-paths)/nixos.img"
else
    log_info "Skipping step 1 (already completed)"
    # Get paths (instant since already built)
    ORIGINAL_KERNEL="$(nix build --impure --accept-flake-config ".#extracted-kernel-${BOARD}" --print-out-paths)/p2.bin"
    PATCHED_INITRAMFS="$(nix build --impure --accept-flake-config ".#initramfs-patching-${BOARD}" --print-out-paths)/patched-initramfs"
    RAW_ROOTFS_IMG="$(nix build --impure --accept-flake-config ".#${RAW_ROOTFS_ATTR}" --print-out-paths)/nixos.img"
fi

# Validate build results
if [ ! -f "$ORIGINAL_KERNEL" ]; then
	log_error "Kernel binary build failed or missing: $ORIGINAL_KERNEL"
	handle_error "$CURRENT_STEP"
fi

log_info "Original kernel p2: $ORIGINAL_KERNEL"
log_info "Patched initramfs dir: $PATCHED_INITRAMFS"
log_info "Raw rootfs: $RAW_ROOTFS_IMG"

# Build ChromeOS SHIM and determine RECOVERY per policy
SHIM_BIN="$(nix build "${NIX_BUILD_FLAGS[@]}" .#chromeos-shim-${BOARD} --print-out-paths)"
RECOVERY_PATH=""
if [ "${SKIP_RECOVERY:-0}" != "1" ]; then
	if [ -n "${RECOVERY_BIN:-}" ]; then
		RECOVERY_PATH="$RECOVERY_BIN"
	else
		RECOVERY_PATH="$(nix build "${NIX_BUILD_FLAGS[@]}" .#chromeos-recovery-${BOARD} --print-out-paths)/recovery.bin"
	fi
fi
log_info "ChromeOS shim: $SHIM_BIN"
if [ -n "$RECOVERY_PATH" ]; then
	log_info "Recovery image: $RECOVERY_PATH"
else
	log_info "Recovery image: skipped (SKIP_RECOVERY=1 or not provided)"
fi

# === Step 2: Harvest ChromeOS drivers (modules/firmware/modprobe.d) ===
if [ "$START_STEP" -le 2 ]; then
	HARVEST_OUT="$WORKDIR/harvested"
	mkdir -p "$HARVEST_OUT"
	CURRENT_STEP="2/15"
	log_step "$CURRENT_STEP" "Harvest ChromeOS drivers"
	if [ -n "$RECOVERY_PATH" ]; then
		bash tools/harvest-drivers.sh --shim "$SHIM_BIN" --recovery "$RECOVERY_PATH" --out "$HARVEST_OUT" || { log_error "Driver harvest failed with recovery image"; handle_error "$CURRENT_STEP"; }
	else
		bash tools/harvest-drivers.sh --shim "$SHIM_BIN" --out "$HARVEST_OUT" || { log_error "Driver harvest failed without recovery image"; handle_error "$CURRENT_STEP"; }
	fi
else
	log_info "Skipping step 2 (already completed)"
	HARVEST_OUT="$WORKDIR/harvested"
fi

# === Step 3: Augment firmware with upstream ChromiumOS linux-firmware ===
if [ "$START_STEP" -le 3 ]; then
	if [ "${FIRMWARE_UPSTREAM:-1}" != "0" ]; then
		CURRENT_STEP="3/15"
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
else
	log_info "Skipping step 3 (already completed)"
fi

# === Step 4: Prune unused firmware files ===
if [ "$START_STEP" -le 4 ]; then
	if [ -d "$HARVEST_OUT/lib/firmware" ]; then
		CURRENT_STEP="4/15"
		log_step "$CURRENT_STEP" "Prune unused firmware files"
		# More robust path resolution
		SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
		if [ -f "$SCRIPT_DIR/tools/harvest-drivers.sh" ]; then
			source "$SCRIPT_DIR/tools/harvest-drivers.sh"
			prune_unused_firmware "$HARVEST_OUT/lib/firmware"
		else
			log_warn "harvest-drivers.sh not found; skipping firmware pruning"
		fi
	fi
else
	log_info "Skipping step 4 (already completed)"
fi

# === Step 5: Calculate vendor partition size AFTER firmware augmentation ===
if [ "$START_STEP" -le 5 ]; then
	CURRENT_STEP="5/15"
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
else
	log_info "Skipping step 5 (already completed)"
	# Recalculate values needed for later steps
	VENDOR_SRC_SIZE_MB=0
	if [ -d "$HARVEST_OUT/lib/modules" ]; then
		 VENDOR_SRC_SIZE_MB=$((VENDOR_SRC_SIZE_MB + $(sudo du -sm "$HARVEST_OUT/lib/modules" | cut -f1)))
	fi
	if [ -d "$HARVEST_OUT/lib/firmware" ]; then
		 VENDOR_SRC_SIZE_MB=$((VENDOR_SRC_SIZE_MB + $(sudo du -sm "$HARVEST_OUT/lib/firmware" | cut -f1)))
	fi
	VENDOR_PART_SIZE=$(((VENDOR_SRC_SIZE_MB * 115 / 100) + 20))
fi

# === Step 6: Copy raw rootfs image ===
if [ "$START_STEP" -le 6 ]; then
	CURRENT_STEP="6/15"
	log_step "$CURRENT_STEP" "Copy raw rootfs image"
	pv "$RAW_ROOTFS_IMG" > "$WORKDIR/rootfs.img"
	
else
	log_info "Skipping step 6 (already completed)"
fi

# === Step 7: Optimize Nix store in raw rootfs ===
if [ "$START_STEP" -le 7 ]; then
	CURRENT_STEP="7/15"
	log_step "$CURRENT_STEP" "Optimize Nix store in raw rootfs"
	LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img") || { log_error "Failed to setup loop device for rootfs optimization"; handle_error "$CURRENT_STEP"; }
	safe_exec sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs" || { log_error "Failed to mount rootfs for optimization"; handle_error "$CURRENT_STEP"; }
	log_info "Running nix-store --optimise on raw rootfs (may take a while)..."
	safe_exec sudo nix-store --store "$WORKDIR/mnt_src_rootfs" --optimise || true
	log_info "Store optimization complete"
	safe_exec sudo umount "$WORKDIR/mnt_src_rootfs"
	safe_exec sudo losetup -d "$LOOPROOT"
	LOOPROOT=""
	
else
	log_info "Skipping step 7 (already completed)"
fi

# === Step 8: Calculate rootfs size ===
if [ "$START_STEP" -le 8 ]; then
	CURRENT_STEP="8/15"
	log_step "$CURRENT_STEP" "Calculate rootfs size"
	LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
	safe_exec sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
	ROOTFS_SIZE_MB=$(sudo du -sm "$WORKDIR/mnt_src_rootfs" | cut -f1)
	log_info "Rootfs content size: ${ROOTFS_SIZE_MB} MB"
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
	
else
	log_info "Skipping step 8 (already completed)"
	# Recalculate values needed for later steps
	LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
	safe_exec sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
	ROOTFS_SIZE_MB=$(sudo du -sm "$WORKDIR/mnt_src_rootfs" | cut -f1)
	safe_exec sudo umount "$WORKDIR/mnt_src_rootfs"
	safe_exec sudo losetup -d "$LOOPROOT"
	LOOPROOT=""
	ROOTFS_PART_SIZE=$(((ROOTFS_SIZE_MB * 110 / 100) + 100))
	VENDOR_START_MB=54
	VENDOR_END_MB=$((VENDOR_START_MB + VENDOR_PART_SIZE))
	TOTAL_SIZE_MB=$((1 + 32 + 20 + VENDOR_PART_SIZE + ROOTFS_PART_SIZE))
fi

# === Step 9: Create empty image ===
if [ "$START_STEP" -le 9 ]; then
	CURRENT_STEP="9/15"
	log_step "$CURRENT_STEP" "Create empty image"
	fallocate -l ${TOTAL_SIZE_MB}M "$IMAGE"
	
else
	log_info "Skipping step 9 (already completed)"
fi

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
if [ "$START_STEP" -le 10 ]; then
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
    
else
	log_info "Skipping step 10 (already completed)"
fi

# === Step 11: Setup loop device ===
if [ "$START_STEP" -le 11 ]; then
	CURRENT_STEP="11/15"
	log_step "$CURRENT_STEP" "Setup loop device"
	LOOPDEV=$(sudo losetup --show -fP "$IMAGE") || { log_error "Failed to setup loop device for $IMAGE"; handle_error "$CURRENT_STEP"; }
	log_info "Loop device: $LOOPDEV"

	# Set ChromeOS boot flags on p2
	log_info "Setting ChromeOS boot flags on KERNEL partition..."
	safe_exec sudo cgpt add -i 2 -S 1 -T 5 -P 10 "$LOOPDEV" || { log_error "Failed to set ChromeOS boot flags"; handle_error "$CURRENT_STEP"; }
	
else
	log_info "Skipping step 11 (already completed)"
	# Need to set up loop device for later steps
	LOOPDEV=$(sudo losetup --show -fP "$IMAGE")
fi

# === Step 12: Format partitions ===
if [ "$START_STEP" -le 12 ]; then
	CURRENT_STEP="12/15"
	log_step "$CURRENT_STEP" "Format partitions"
	# Use conservative ext4 features for ChromeOS kernel compatibility (avoid EINVAL on mount)
	MKFS_EXT4_FLAGS="-O ^orphan_file,^metadata_csum_seed"
	safe_exec sudo mkfs.ext4 -q "$MKFS_EXT4_FLAGS" "${LOOPDEV}p1"
	safe_exec sudo dd if="$ORIGINAL_KERNEL" of="${LOOPDEV}p2" bs=1M conv=fsync status=progress
	safe_exec sudo mkfs.ext2 -q "${LOOPDEV}p3"

	if [ "$HAS_VENDOR_PARTITION" -eq 1 ]; then
	    # Vendor partition (drivers/firmware donor) - p4
	    safe_exec sudo mkfs.ext4 -q -O ^has_journal,^orphan_file,^metadata_csum_seed \
	      -L "shimboot_vendor" "${LOOPDEV}p4"
	    # Rootfs is p5
	    safe_exec sudo mkfs.ext4 -q -L "$ROOTFS_NAME" "$MKFS_EXT4_FLAGS" "${LOOPDEV}p5"
	else
	    # Rootfs directly as p4
	    safe_exec sudo mkfs.ext4 -q -L "$ROOTFS_NAME" "$MKFS_EXT4_FLAGS" "${LOOPDEV}p4"
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
	
else
	log_info "Skipping step 12 (already completed)"
	# Set MKFS_EXT4_FLAGS for later use
	MKFS_EXT4_FLAGS="-O ^orphan_file,^metadata_csum_seed"
fi

# === Step 13: Populate bootloader partition ===
if [ "$START_STEP" -le 13 ]; then
	CURRENT_STEP="13/15"
	log_step "$CURRENT_STEP" "Populate bootloader partition"
	safe_exec sudo mount "${LOOPDEV}p3" "$WORKDIR/mnt_bootloader" || { log_error "Failed to mount bootloader partition"; handle_error "$CURRENT_STEP"; }
	total_bytes=$(sudo du -sb "$PATCHED_INITRAMFS" | cut -f1)
	(cd "$PATCHED_INITRAMFS" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_bootloader" && sudo tar xf -) || { log_error "Failed to populate bootloader partition"; handle_error "$CURRENT_STEP"; }
	safe_exec sudo umount "$WORKDIR/mnt_bootloader"
	
else
	log_info "Skipping step 13 (already completed)"
fi

# === Step 14: Populate rootfs partition ===
if [ "$START_STEP" -le 14 ]; then
	CURRENT_STEP="14/15"
	log_step "$CURRENT_STEP" "Populate rootfs partition (now p${ROOTFS_PARTITION_INDEX})"
	LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
	safe_exec sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
	safe_exec sudo mount "${LOOPDEV}p${ROOTFS_PARTITION_INDEX}" "$WORKDIR/mnt_rootfs"
	total_bytes=$(sudo du -sb "$WORKDIR/mnt_src_rootfs" | cut -f1)
	(cd "$WORKDIR/mnt_src_rootfs" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_rootfs" && sudo tar xf -)

	# Get username from userConfig
	USERNAME=$(nix eval "${NIX_BUILD_FLAGS[@]}" --expr '(import ./shimboot_config/user-config.nix {}).user.username' --json | jq -r .)
	log_info "Using username from userConfig: $USERNAME"

	# === Step 14: Clone nixos-config repository into rootfs ===
	log_step "$CURRENT_STEP" "Clone nixos-config repository into rootfs"
	NIXOS_CONFIG_DEST="$WORKDIR/mnt_rootfs/home/$USERNAME/nixos-config"

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
	  sudo tee "$NIXOS_CONFIG_DEST/.shimboot_branch" > /dev/null <<EOF
# Shimboot build information
BUILD_DATE=$BUILD_DATE
GIT_BRANCH=$GIT_BRANCH
GIT_COMMIT=$GIT_COMMIT
GIT_CHANGES=$GIT_STATUS
GIT_REMOTE=$GIT_REMOTE
EOF

	  # Create detailed build metadata file
	  sudo tee "$NIXOS_CONFIG_DEST/.shimboot_build_info" > /dev/null <<EOF
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
	safe_exec sudo tee "$WORKDIR/mnt_rootfs/etc/shimboot-build.json" > /dev/null <<EOF
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
	
else
	log_info "Skipping step 14 (already completed)"
	# Need to mount rootfs for step 15
	safe_exec sudo mount "${LOOPDEV}p${ROOTFS_PARTITION_INDEX}" "$WORKDIR/mnt_rootfs" 2>/dev/null || true
fi


# === Step 15: Driver handling functions ===
# Extract functions first to eliminate code duplication

populate_vendor() {
	if [ ! -b "${LOOPDEV}p4" ]; then
		log_error "Vendor partition p4 not found on ${LOOPDEV}"
		handle_error "$CURRENT_STEP"
	fi
	
	log_step "15/15" "Populate vendor partition (p4) with harvested drivers (/lib/modules, /lib/firmware)"
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
	log_step "15/15" "Inject drivers into rootfs (p${ROOTFS_PARTITION_INDEX}) (/lib/modules, /lib/firmware, modprobe.d)"
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
if [ "$START_STEP" -le 15 ]; then
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
	log_info "✅ Final image created at: $IMAGE"
	
else
	log_info "Skipping step 15 (already completed)"
	# Clean up any remaining mounts
	if mountpoint -q "$WORKDIR/mnt_rootfs" 2>/dev/null; then
		safe_exec sudo umount "$WORKDIR/mnt_rootfs" 2>/dev/null || true
	fi
	if [ -n "${LOOPDEV:-}" ] && losetup "${LOOPDEV}" &>/dev/null; then
		safe_exec sudo losetup -d "$LOOPDEV" 2>/dev/null || true
		LOOPDEV=""
	fi
log_info "✅ Final image already exists at: $IMAGE"
fi

# Add before final cleanup
show_cache_stats() {
	   log_step "Stats" "Build cache statistics"
	   
	   if [ -f /nix/var/log/nix/drvs ]; then
	       local total_derivations=$(find /nix/var/log/nix/drvs -type f | wc -l)
	       log_info "Total derivations built: $total_derivations"
	   fi
	   
	   # Show what was fetched vs built
	   if command -v nix >/dev/null 2>&1; then
	       log_info "Checking recent store operations..."
	       nix store diff-closures /nix/var/nix/profiles/system-{1,2}-link 2>/dev/null | head -n 20 || true
	   fi
}

# === Optional cleanup of old shimboot rootfs generations ===
if [ "${CLEANUP_ROOTFS:-0}" -eq 1 ]; then
	CURRENT_STEP="Cleanup"
	log_step "$CURRENT_STEP" "Pruning older shimboot rootfs generations"
	# Build arguments for cleanup script
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

# === Optional inspection ===
# Call at end of script
show_cache_stats

# === Final instruction for Cachix push ===
log_info "To push to Cachix, run:"
log_info "  ./tools/push-to-cachix.sh --board $BOARD --rootfs $ROOTFS_FLAVOR --drivers $DRIVERS_MODE --image $IMAGE"

# === Optional inspection ===
if [ "$INSPECT_AFTER" = "--inspect" ]; then
	CURRENT_STEP="Inspect"
	log_step "$CURRENT_STEP" "Partition table and init check"
	safe_exec sudo partx -o NR,START,END,SIZE,TYPE,NAME,UUID -g --show "$IMAGE"
	LOOPDEV=$(sudo losetup --show -fP "$IMAGE")
	mkdir -p "$WORKDIR/inspect_rootfs"
	safe_exec sudo mount "${LOOPDEV}p5" "$WORKDIR/inspect_rootfs"  # Changed from p4 to p5
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