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
#   ./assemble-final.sh --board dedede --rootfs full

set -euo pipefail

# Elevate to root so nix-daemon treats this client as trusted; required for substituters/trusted-public-keys
# Use -H to set HOME to /root to avoid "$HOME is not owned by you" warnings under sudo.
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "[assemble-final] Re-executing with sudo -H..."
	exec sudo -H "$0" "$@"
fi

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

# Ensure unfree packages are allowed for nix builds that require ChromeOS tools/firmware
export NIXPKGS_ALLOW_UNFREE="${NIXPKGS_ALLOW_UNFREE:-1}"

# === Config ===
SYSTEM="x86_64-linux"
WORKDIR="$(pwd)/work"
IMAGE="$WORKDIR/shimboot.img"

# Board selection (default: dedede)
BOARD="${BOARD:-dedede}"
ROOTFS_NAME="${ROOTFS_NAME:-nixos}"

# CLI parsing: --rootfs {full|minimal}, --inspect, non-interactive via env ROOTFS_FLAVOR
ROOTFS_FLAVOR="${ROOTFS_FLAVOR:-}"
INSPECT_AFTER=""

# Firmware options
FIRMWARE_UPSTREAM="${FIRMWARE_UPSTREAM:-1}"

# Cleanup options
CLEANUP_ROOTFS=0
CLEANUP_NO_DRY_RUN=0
CLEANUP_KEEP=""

while [ $# -gt 0 ]; do
	case "${1:-}" in
	--board)
		BOARD="${2:-}"
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
	*)
		# Backward compat: if a single arg was passed previously as inspect flag
		if [ "${1:-}" = "--inspect" ]; then
			INSPECT_AFTER="--inspect"
		fi
		shift
		;;
	esac
done

# Interactive prompt if not provided, default to full
if [ -z "${ROOTFS_FLAVOR:-}" ]; then
	if [ -t 0 ]; then
		echo
		echo "[assemble-final] Select rootfs flavor to build:"
		echo "  1) full     (preferred) → uses main configuration (Home Manager, LightDM)"
		echo "  2) minimal  (base-only) → standalone base with Hyprland via greetd"
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

# === Cleanup workspace ===
if [ -d "$WORKDIR" ]; then
	log_warn "Cleaning up old work directory..."
	sudo rm -rf "$WORKDIR"
fi
mkdir -p "$WORKDIR" "$WORKDIR/mnt_src_rootfs" "$WORKDIR/mnt_bootloader" "$WORKDIR/mnt_rootfs"

# === Track loop devices for cleanup ===
LOOPDEV=""
LOOPROOT=""

cleanup() {
	log_info "Cleanup: unmounting and detaching loop devices..."
	set +e

	# Try to unmount known mount points (normal, then lazy if busy)
	for mnt in "$WORKDIR/mnt_rootfs" "$WORKDIR/mnt_bootloader" "$WORKDIR/mnt_src_rootfs" "$WORKDIR/inspect_rootfs" "$WORKDIR/mnt_vendor"; do
		if mountpoint -q "$mnt"; then
			sudo umount "$mnt" || sudo umount -l "$mnt"
		fi
	done

	# Give kernel a moment to release references
	sync
	sleep 0.5

	# Detach any loops recorded in variables if they still exist
	if [ -n "${LOOPDEV:-}" ] && losetup "${LOOPDEV}" &>/dev/null; then
		sudo losetup -d "${LOOPDEV}" || true
	fi
	if [ -n "${LOOPROOT:-}" ] && losetup "${LOOPROOT}" &>/dev/null; then
		sudo losetup -d "${LOOPROOT}" || true
	fi

	# Detach any loop devices still associated with our images (belt and suspenders)
	for img in "$IMAGE" "$WORKDIR/rootfs.img"; do
		if [ -n "${img:-}" ] && [ -e "${img}" ]; then
			while read -r dev; do
				[ -n "$dev" ] || continue
				sudo losetup -d "$dev" || true
			done < <(losetup -j "$img" | cut -d: -f1)
		fi
	done

	set -e
}
trap cleanup EXIT INT TERM

# === Step 0: Build Nix outputs ===
log_step "0/8" "Building Nix outputs"
ORIGINAL_KERNEL="$(nix build --impure --accept-flake-config .#extracted-kernel-${BOARD} --print-out-paths)/p2.bin"
PATCHED_INITRAMFS="$(nix build --impure --accept-flake-config .#initramfs-patching-${BOARD} --print-out-paths)/patched-initramfs"
RAW_ROOTFS_IMG="$(nix build --impure --accept-flake-config .#${RAW_ROOTFS_ATTR} --print-out-paths)/nixos.img"
log_info "Original kernel p2: $ORIGINAL_KERNEL"
log_info "Patched initramfs dir: $PATCHED_INITRAMFS"
log_info "Raw rootfs: $RAW_ROOTFS_IMG"

# Build ChromeOS SHIM and determine RECOVERY per policy
SHIM_BIN="$(nix build --impure --accept-flake-config .#chromeos-shim-${BOARD} --print-out-paths)"
RECOVERY_PATH=""
if [ "${SKIP_RECOVERY:-0}" != "1" ]; then
	if [ -n "${RECOVERY_BIN:-}" ]; then
		RECOVERY_PATH="$RECOVERY_BIN"
	else
		RECOVERY_PATH="$(nix build --impure --accept-flake-config .#chromeos-recovery-${BOARD} --print-out-paths)/recovery.bin"
	fi
fi
log_info "ChromeOS shim: $SHIM_BIN"
if [ -n "$RECOVERY_PATH" ]; then
	log_info "Recovery image: $RECOVERY_PATH"
else
	log_info "Recovery image: skipped (SKIP_RECOVERY=1 or not provided)"
fi

# === Step 0.5: Harvest ChromeOS drivers (modules/firmware/modprobe.d)
HARVEST_OUT="$WORKDIR/harvested"
mkdir -p "$HARVEST_OUT"
log_step "0.5/8" "Harvest ChromeOS drivers"
if [ -n "$RECOVERY_PATH" ]; then
	bash tools/harvest-drivers.sh --shim "$SHIM_BIN" --recovery "$RECOVERY_PATH" --out "$HARVEST_OUT"
else
	bash tools/harvest-drivers.sh --shim "$SHIM_BIN" --out "$HARVEST_OUT"
fi

# === Step 0.6: Augment firmware with upstream ChromiumOS linux-firmware ===
if [ "${FIRMWARE_UPSTREAM:-1}" != "0" ]; then
	log_step "0.6/8" "Augment firmware with upstream linux-firmware"
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

# Decompress module .ko.gz and precompute depmod metadata
if [ -d "$HARVEST_OUT/lib/modules" ]; then
	compressed_files="$(find "$HARVEST_OUT/lib/modules" -type f -name '*.gz' 2>/dev/null || true)"
	if [ -n "$compressed_files" ]; then
		echo "$compressed_files" | xargs -r -n1 gunzip -f || true
	fi
	for kdir in "$HARVEST_OUT/lib/modules/"*; do
		[ -d "$kdir" ] || continue
		kver="$(basename "$kdir")"
		log_info "Running depmod for kernel $kver"
		depmod -b "$HARVEST_OUT" "$kver" || true
	done
else
	log_warn "No harvested modules found under $HARVEST_OUT/lib/modules"
fi

# === Step 1: Copy raw rootfs image ===
log_step "1/8" "Copy raw rootfs image"
cp "$RAW_ROOTFS_IMG" "$WORKDIR/rootfs.img"

# === Step 1.5: Optimize Nix store in raw rootfs ===
log_step "1.5" "Optimize Nix store in raw rootfs"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
log_info "Running nix-store --optimise on raw rootfs (may take a while)..."
sudo nix-store --store "$WORKDIR/mnt_src_rootfs" --optimise || true
log_info "Store optimization complete"
sudo umount "$WORKDIR/mnt_src_rootfs"
sudo losetup -d "$LOOPROOT"
LOOPROOT=""

# === Step 2: Calculate rootfs size ===
log_step "2/8" "Calculate rootfs size"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
ROOTFS_SIZE_MB=$(sudo du -sm "$WORKDIR/mnt_src_rootfs" | cut -f1)
log_info "Rootfs content size: ${ROOTFS_SIZE_MB} MB"
sudo umount "$WORKDIR/mnt_src_rootfs"
sudo losetup -d "$LOOPROOT"
LOOPROOT=""

ROOTFS_PART_SIZE=$(((ROOTFS_SIZE_MB * 12 / 10) + 5))

# Estimate vendor partition size from harvested drivers
VENDOR_SRC_SIZE_MB=0
if [ -d "$HARVEST_OUT/lib/modules" ]; then
	VENDOR_SRC_SIZE_MB=$((VENDOR_SRC_SIZE_MB + $(sudo du -sm "$HARVEST_OUT/lib/modules" | cut -f1)))
fi
if [ -d "$HARVEST_OUT/lib/firmware" ]; then
	VENDOR_SRC_SIZE_MB=$((VENDOR_SRC_SIZE_MB + $(sudo du -sm "$HARVEST_OUT/lib/firmware" | cut -f1)))
fi

if [ "$VENDOR_SRC_SIZE_MB" -le 0 ]; then
	# Default vendor size when no harvest is available
	VENDOR_PART_SIZE=256
	log_warn "No harvested drivers; defaulting vendor partition to ${VENDOR_PART_SIZE} MB"
else
	# 20% headroom + 32MB buffer
	VENDOR_PART_SIZE=$(((VENDOR_SRC_SIZE_MB * 12 / 10) + 32))
fi

# Compute end of vendor and total size (MiB)
# NEW LAYOUT: vendor comes before rootfs
VENDOR_START_MB=54
VENDOR_END_MB=$((VENDOR_START_MB + VENDOR_PART_SIZE))
TOTAL_SIZE_MB=$((1 + 32 + 20 + VENDOR_PART_SIZE + ROOTFS_PART_SIZE))
log_info "Vendor partition size: ${VENDOR_PART_SIZE} MB"
log_info "Rootfs partition size: ${ROOTFS_PART_SIZE} MB (initial, expandable)"
log_info "Total image size: ${TOTAL_SIZE_MB} MB"

# === Step 3: Create empty image ===
log_step "3/8" "Create empty image"
fallocate -l ${TOTAL_SIZE_MB}M "$IMAGE"

# === Step 4: Partition image ===
log_step "4/8" "Partition image (GPT, ChromeOS GUIDs, vendor before rootfs)"
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

log_info "Partition table:"
sudo partx -o NR,START,END,SIZE,TYPE,NAME,UUID -g --show "$IMAGE"

# === Step 5: Setup loop device ===
log_step "5/8" "Setup loop device"
LOOPDEV=$(sudo losetup --show -fP "$IMAGE")
log_info "Loop device: $LOOPDEV"

# Set ChromeOS boot flags on p2
log_info "Setting ChromeOS boot flags on KERNEL partition..."
sudo cgpt add -i 2 -S 1 -T 5 -P 10 "$LOOPDEV"

# === Step 6: Format partitions ===
log_step "6/8" "Format partitions"
# Use conservative ext4 features for ChromeOS kernel compatibility (avoid EINVAL on mount)
MKFS_EXT4_FLAGS="-O ^orphan_file,^metadata_csum_seed"
sudo mkfs.ext4 -q "$MKFS_EXT4_FLAGS" "${LOOPDEV}p1"
sudo dd if="$ORIGINAL_KERNEL" of="${LOOPDEV}p2" bs=1M conv=fsync status=progress
sudo mkfs.ext2 -q "${LOOPDEV}p3"
# Vendor partition (drivers/firmware donor) - now p4
sudo mkfs.ext4 -q -L "shimboot_vendor" "$MKFS_EXT4_FLAGS" "${LOOPDEV}p4"
# IMPORTANT: Label rootfs as $ROOTFS_NAME so NixOS can resolve fileSystems."/".device = /dev/disk/by-label/${ROOTFS_NAME}
# Rootfs is now p5
sudo mkfs.ext4 -q -L "$ROOTFS_NAME" "$MKFS_EXT4_FLAGS" "${LOOPDEV}p5"

# === Step 7: Populate bootloader partition ===
log_step "7/8" "Populate bootloader partition"
sudo mount "${LOOPDEV}p3" "$WORKDIR/mnt_bootloader"
total_bytes=$(sudo du -sb "$PATCHED_INITRAMFS" | cut -f1)
(cd "$PATCHED_INITRAMFS" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_bootloader" && sudo tar xf -)
sudo umount "$WORKDIR/mnt_bootloader"

# === Step 8: Populate rootfs partition ===
log_step "8/8" "Populate rootfs partition (now p5)"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
sudo mount "${LOOPDEV}p5" "$WORKDIR/mnt_rootfs"  # Changed from p4 to p5
total_bytes=$(sudo du -sb "$WORKDIR/mnt_src_rootfs" | cut -f1)
(cd "$WORKDIR/mnt_src_rootfs" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_rootfs" && sudo tar xf -)

# Get username from userConfig
USERNAME=$(nix eval --impure --expr '(import ./shimboot_config/user-config.nix {}).user.username' --json | jq -r .)
log_info "Using username from userConfig: $USERNAME"

# === Step 8.2: Clone nixos-config repository into rootfs ===
log_step "8.2" "Clone nixos-config repository into rootfs"
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
    sudo rm -rf "$NIXOS_CONFIG_DEST"
  fi

  # Clone the repository
  log_info "Cloning nixos-config repository..."
  sudo git clone --no-local "$(pwd)" "$NIXOS_CONFIG_DEST"

  # Switch to the same branch as the source repository
  if [ "$GIT_BRANCH" != "unknown" ]; then
    log_info "Switching to branch: $GIT_BRANCH"
    sudo git -C "$NIXOS_CONFIG_DEST" checkout "$GIT_BRANCH" || log_warn "Failed to checkout branch $GIT_BRANCH"
  fi

  # Set ownership to user
  sudo chown -R 1000:1000 "$NIXOS_CONFIG_DEST"

  # Create branch info file
  sudo tee "$NIXOS_CONFIG_DEST/.shimboot_branch" > /dev/null <<EOF
# Shimboot build information
BUILD_DATE=$BUILD_DATE
GIT_BRANCH=$GIT_BRANCH
GIT_COMMIT=$GIT_COMMIT
GIT_CHANGES=$GIT_STATUS
GIT_REMOTE=$GIT_REMOTE
EOF

  log_info "Cloned nixos-config: $GIT_BRANCH ($GIT_COMMIT) with $GIT_STATUS changes"
else
  log_warn "Git not available or not a git repository, skipping nixos-config clone"
fi

# Source rootfs unmounted; target rootfs remains mounted briefly before finalization
sudo umount "$WORKDIR/mnt_src_rootfs"
sudo losetup -d "$LOOPROOT"
LOOPROOT=""


# === Step 8.1: Inject harvested drivers into rootfs (optional) ===
# DRIVERS_MODE set earlier (default 'vendor'); valid: vendor|inject|none

case "$DRIVERS_MODE" in
vendor | CROSDRV)
	log_step "8.1" "Populate vendor partition (p4) with harvested drivers (/lib/modules, /lib/firmware)"
	if [ ! -b "${LOOPDEV}p4" ]; then
		log_error "Vendor partition p4 not found on ${LOOPDEV}"
	else
		sudo mkdir -p "$WORKDIR/mnt_vendor"
		sudo mount "${LOOPDEV}p4" "$WORKDIR/mnt_vendor"
		sudo mkdir -p "$WORKDIR/mnt_vendor/lib/modules" "$WORKDIR/mnt_vendor/lib/firmware"

		if [ -d "$HARVEST_OUT/lib/modules" ]; then
			log_info "Copying modules to vendor..."
			sudo cp -a "$HARVEST_OUT/lib/modules/." "$WORKDIR/mnt_vendor/lib/modules/"
		else
			log_warn "No harvested lib/modules; nothing to place into vendor partition"
		fi

		if [ -d "$HARVEST_OUT/lib/firmware" ]; then
			log_info "Copying firmware to vendor..."
			sudo cp -a "$HARVEST_OUT/lib/firmware/." "$WORKDIR/mnt_vendor/lib/firmware/"
		else
			log_warn "No harvested lib/firmware; nothing to place into vendor partition"
		fi

		sudo sync
		sudo umount "$WORKDIR/mnt_vendor"
	fi
	;;
both)
	log_step "8.1" "Populate vendor partition (p4) with harvested drivers, then inject into rootfs (p5)"
	if [ ! -b "${LOOPDEV}p4" ]; then
		log_error "Vendor partition p4 not found on ${LOOPDEV}"
	else
		sudo mkdir -p "$WORKDIR/mnt_vendor"
		sudo mount "${LOOPDEV}p4" "$WORKDIR/mnt_vendor"
		sudo mkdir -p "$WORKDIR/mnt_vendor/lib/modules" "$WORKDIR/mnt_vendor/lib/firmware"

		if [ -d "$HARVEST_OUT/lib/modules" ]; then
			log_info "Copying modules to vendor..."
			sudo cp -a "$HARVEST_OUT/lib/modules/." "$WORKDIR/mnt_vendor/lib/modules/"
		else
			log_warn "No harvested lib/modules; nothing to place into vendor partition"
		fi

		if [ -d "$HARVEST_OUT/lib/firmware" ]; then
			log_info "Copying firmware to vendor..."
			sudo cp -a "$HARVEST_OUT/lib/firmware/." "$WORKDIR/mnt_vendor/lib/firmware/"
		else
			log_warn "No harvested lib/firmware; nothing to place into vendor partition"
		fi

		sudo sync
		sudo umount "$WORKDIR/mnt_vendor"
	fi

	log_step "8.1b" "Inject drivers into rootfs (p5) (/lib/modules, /lib/firmware, modprobe.d)"
	if [ -d "$HARVEST_OUT/lib/modules" ]; then
		sudo rm -rf "$WORKDIR/mnt_rootfs/lib/modules"
		sudo mkdir -p "$WORKDIR/mnt_rootfs/lib"
		sudo cp -a "$HARVEST_OUT/lib/modules" "$WORKDIR/mnt_rootfs/lib/modules"
	else
		log_warn "No harvested lib/modules; skipping module injection"
	fi
	if [ -d "$HARVEST_OUT/lib/firmware" ]; then
		sudo mkdir -p "$WORKDIR/mnt_rootfs/lib/firmware"
		sudo cp -a "$HARVEST_OUT/lib/firmware/." "$WORKDIR/mnt_rootfs/lib/firmware/"
	else
		log_warn "No harvested lib/firmware; skipping firmware injection"
	fi
	if [ -d "$HARVEST_OUT/modprobe.d" ]; then
		sudo mkdir -p "$WORKDIR/mnt_rootfs/lib/modprobe.d" "$WORKDIR/mnt_rootfs/etc/modprobe.d"
		sudo cp -a "$HARVEST_OUT/modprobe.d/." "$WORKDIR/mnt_rootfs/lib/modprobe.d/" 2>/dev/null || true
		sudo cp -a "$HARVEST_OUT/modprobe.d/." "$WORKDIR/mnt_rootfs/etc/modprobe.d/" 2>/dev/null || true
	fi
	;;
inject)
	log_step "8.1" "Inject drivers into rootfs (p5) (/lib/modules, /lib/firmware, modprobe.d)"
	if [ -d "$HARVEST_OUT/lib/modules" ]; then
		sudo rm -rf "$WORKDIR/mnt_rootfs/lib/modules"
		sudo mkdir -p "$WORKDIR/mnt_rootfs/lib"
		sudo cp -a "$HARVEST_OUT/lib/modules" "$WORKDIR/mnt_rootfs/lib/modules"
	else
		log_warn "No harvested lib/modules; skipping module injection"
	fi
	if [ -d "$HARVEST_OUT/lib/firmware" ]; then
		sudo mkdir -p "$WORKDIR/mnt_rootfs/lib/firmware"
		sudo cp -a "$HARVEST_OUT/lib/firmware/." "$WORKDIR/mnt_rootfs/lib/firmware/"
	else
		log_warn "No harvested lib/firmware; skipping firmware injection"
	fi
	if [ -d "$HARVEST_OUT/modprobe.d" ]; then
		sudo mkdir -p "$WORKDIR/mnt_rootfs/lib/modprobe.d" "$WORKDIR/mnt_rootfs/etc/modprobe.d"
		sudo cp -a "$HARVEST_OUT/modprobe.d/." "$WORKDIR/mnt_rootfs/lib/modprobe.d/" 2>/dev/null || true
		sudo cp -a "$HARVEST_OUT/modprobe.d/." "$WORKDIR/mnt_rootfs/etc/modprobe.d/" 2>/dev/null || true
	fi
	;;
none)
	log_info "DRIVERS_MODE=none; leaving rootfs unchanged"
	;;
*)
	log_warn "Unknown DRIVERS_MODE='${DRIVERS_MODE}', defaulting to vendor populate"
	if [ -b "${LOOPDEV}p4" ]; then
		sudo mkdir -p "$WORKDIR/mnt_vendor"
		sudo mount "${LOOPDEV}p4" "$WORKDIR/mnt_vendor"
		sudo mkdir -p "$WORKDIR/mnt_vendor/lib/modules" "$WORKDIR/mnt_vendor/lib/firmware"
		if [ -d "$HARVEST_OUT/lib/modules" ]; then
			sudo cp -a "$HARVEST_OUT/lib/modules/." "$WORKDIR/mnt_vendor/lib/modules/"
		fi
		if [ -d "$HARVEST_OUT/lib/firmware" ]; then
			sudo cp -a "$HARVEST_OUT/lib/firmware/." "$WORKDIR/mnt_vendor/lib/firmware/"
		fi
		sudo sync
		sudo umount "$WORKDIR/mnt_vendor"
	else
		log_error "Vendor partition p4 not found on ${LOOPDEV}"
	fi
	;;
esac

# Unmount rootfs
sudo umount "$WORKDIR/mnt_rootfs"

# Detach loop devices used for target image
sudo losetup -d "$LOOPDEV"
LOOPDEV=""
log_info "✅ Final image created at: $IMAGE"

# === Optional cleanup of old shimboot rootfs generations ===
if [ "${CLEANUP_ROOTFS:-0}" -eq 1 ]; then
	log_step "Cleanup" "Pruning older shimboot rootfs generations"
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
if [ "$INSPECT_AFTER" = "--inspect" ]; then
	log_step "Inspect" "Partition table and init check"
	sudo partx -o NR,START,END,SIZE,TYPE,NAME,UUID -g --show "$IMAGE"
	LOOPDEV=$(sudo losetup --show -fP "$IMAGE")
	mkdir -p "$WORKDIR/inspect_rootfs"
	sudo mount "${LOOPDEV}p5" "$WORKDIR/inspect_rootfs"  # Changed from p4 to p5
	sudo ls -l "$WORKDIR/inspect_rootfs"
	if [ -f "$WORKDIR/inspect_rootfs/sbin/init" ]; then
		log_info "Init found at /sbin/init → $(file -b "$WORKDIR/inspect_rootfs/sbin/init")"
	elif [ -f "$WORKDIR/inspect_rootfs/init" ]; then
		log_info "Init found at /init → $(file -b "$WORKDIR/inspect_rootfs/init")"
	else
		log_error "Init missing"
	fi
	sudo umount "$WORKDIR/inspect_rootfs"
	sudo losetup -d "$LOOPDEV"
fi