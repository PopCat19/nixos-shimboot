#!/usr/bin/env bash
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
ROOTFS_NAME="${ROOTFS_NAME:-nixos}"

# CLI parsing: --rootfs {full|minimal}, --inspect, non-interactive via env ROOTFS_FLAVOR
ROOTFS_FLAVOR="${ROOTFS_FLAVOR:-}"
INSPECT_AFTER=""

# Cleanup options
CLEANUP_ROOTFS=0
CLEANUP_NO_DRY_RUN=0
CLEANUP_KEEP=""

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --rootfs)
      ROOTFS_FLAVOR="${2:-}"
      shift 2
      ;;
    --inspect)
      INSPECT_AFTER="--inspect"
      shift
      ;;
    --cleanup-rootfs)
      CLEANUP_ROOTFS=1
      shift
      ;;
    --cleanup-no-dry-run|--no-dry-run)
      CLEANUP_NO_DRY_RUN=1
      shift
      ;;
    --cleanup-keep|--keep)
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
    for mnt in "$WORKDIR/mnt_rootfs" "$WORKDIR/mnt_bootloader" "$WORKDIR/mnt_src_rootfs" "$WORKDIR/inspect_rootfs"; do
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
ORIGINAL_KERNEL="$(nix build --impure --accept-flake-config .#extracted-kernel --print-out-paths)/p2.bin"
PATCHED_INITRAMFS="$(nix build --impure --accept-flake-config .#initramfs-patching --print-out-paths)/patched-initramfs"
RAW_ROOTFS_IMG="$(nix build --impure --accept-flake-config .#${RAW_ROOTFS_ATTR} --print-out-paths)/nixos.img"
log_info "Original kernel p2: $ORIGINAL_KERNEL"
log_info "Patched initramfs dir: $PATCHED_INITRAMFS"
log_info "Raw rootfs: $RAW_ROOTFS_IMG"

# Build ChromeOS SHIM and determine RECOVERY per policy
SHIM_BIN="$(nix build --impure --accept-flake-config .#chromeos-shim --print-out-paths)"
RECOVERY_PATH=""
if [ "${SKIP_RECOVERY:-0}" != "1" ]; then
    if [ -n "${RECOVERY_BIN:-}" ]; then
        RECOVERY_PATH="$RECOVERY_BIN"
    else
        RECOVERY_PATH="$(nix build --impure --accept-flake-config .#chromeos-recovery --print-out-paths)/recovery.bin"
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
    bash scripts/harvest-drivers.sh --shim "$SHIM_BIN" --recovery "$RECOVERY_PATH" --out "$HARVEST_OUT"
else
    bash scripts/harvest-drivers.sh --shim "$SHIM_BIN" --out "$HARVEST_OUT"
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

# === Step 2: Calculate rootfs size ===
log_step "2/8" "Calculate rootfs size"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
ROOTFS_SIZE_MB=$(sudo du -sm "$WORKDIR/mnt_src_rootfs" | cut -f1)
log_info "Rootfs content size: ${ROOTFS_SIZE_MB} MB"
sudo umount "$WORKDIR/mnt_src_rootfs"
sudo losetup -d "$LOOPROOT"
LOOPROOT=""

ROOTFS_PART_SIZE=$(( (ROOTFS_SIZE_MB * 12 / 10) + 5 ))
TOTAL_SIZE_MB=$((1 + 32 + 20 + ROOTFS_PART_SIZE))
log_info "Rootfs partition size: ${ROOTFS_PART_SIZE} MB"
log_info "Total image size: ${TOTAL_SIZE_MB} MB"

# === Step 3: Create empty image ===
log_step "3/8" "Create empty image"
fallocate -l ${TOTAL_SIZE_MB}M "$IMAGE"

# === Step 4: Partition image ===
log_step "4/8" "Partition image (GPT, ChromeOS GUIDs)"
parted --script "$IMAGE" \
  mklabel gpt \
  mkpart stateful ext4 1MiB 2MiB \
  name 1 STATE \
  mkpart kernel  2MiB 34MiB \
  name 2 KERNEL \
  type 2 FE3A2A5D-4F32-41A7-B725-ACCC3285A309 \
  mkpart bootloader ext2 34MiB 54MiB \
  name 3 BOOT \
  type 3 3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC \
  mkpart rootfs ext4 54MiB 100% \
  name 4 "shimboot_rootfs:${ROOTFS_NAME}"

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
sudo mkfs.ext4 -q $MKFS_EXT4_FLAGS "${LOOPDEV}p1"
sudo dd if="$ORIGINAL_KERNEL" of="${LOOPDEV}p2" bs=1M conv=fsync status=progress
sudo mkfs.ext2 -q "${LOOPDEV}p3"
# IMPORTANT: Label rootfs as $ROOTFS_NAME so NixOS can resolve fileSystems."/".device = /dev/disk/by-label/${ROOTFS_NAME}
sudo mkfs.ext4 -q -L "$ROOTFS_NAME" $MKFS_EXT4_FLAGS "${LOOPDEV}p4"

# === Step 7: Populate bootloader partition ===
log_step "7/8" "Populate bootloader partition"
sudo mount "${LOOPDEV}p3" "$WORKDIR/mnt_bootloader"
total_bytes=$(sudo du -sb "$PATCHED_INITRAMFS" | cut -f1)
(cd "$PATCHED_INITRAMFS" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_bootloader" && sudo tar xf -)
sudo umount "$WORKDIR/mnt_bootloader"

# === Step 8: Populate rootfs partition ===
log_step "8/8" "Populate rootfs partition"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
sudo mount "${LOOPDEV}p4" "$WORKDIR/mnt_rootfs"
total_bytes=$(sudo du -sb "$WORKDIR/mnt_src_rootfs" | cut -f1)
(cd "$WORKDIR/mnt_src_rootfs" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_rootfs" && sudo tar xf -)

# Source rootfs unmounted; target rootfs remains mounted briefly before finalization
sudo umount "$WORKDIR/mnt_src_rootfs"
sudo losetup -d "$LOOPROOT"
LOOPROOT=""

# === Step 8.1: Inject harvested drivers into rootfs (optional) ===
DRIVERS_MODE="${DRIVERS_MODE:-inject}"

case "$DRIVERS_MODE" in
  inject)
    log_step "8.1" "Inject drivers into rootfs (/lib/modules, /lib/firmware, modprobe.d)"
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
  vendor|CROSDRV)
    log_warn "DRIVERS_MODE=${DRIVERS_MODE} requested, but vendor partition is not yet implemented in this assembler"
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
    CLEANUP_CMD=(sudo bash scripts/cleanup-shimboot-rootfs.sh --results-dir "$(pwd)")
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
    sudo mount "${LOOPDEV}p4" "$WORKDIR/inspect_rootfs"
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