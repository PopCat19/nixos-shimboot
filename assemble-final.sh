#!/usr/bin/env bash
set -euo pipefail

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

# === Config ===
SYSTEM="x86_64-linux"
WORKDIR="$(pwd)/work"
IMAGE="$WORKDIR/shimboot.img"
ROOTFS_NAME="${ROOTFS_NAME:-nixos}"
INSPECT_AFTER="${1:-}"

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
    log_info "Unmounting and detaching loop devices..."
    set +e
    for mnt in "$WORKDIR/mnt_rootfs" "$WORKDIR/mnt_bootloader" "$WORKDIR/mnt_src_rootfs"; do
        if mountpoint -q "$mnt"; then sudo umount "$mnt"; fi
    done
    if [ -n "$LOOPDEV" ] && losetup "$LOOPDEV" &>/dev/null; then sudo losetup -d "$LOOPDEV"; fi
    if [ -n "$LOOPROOT" ] && losetup "$LOOPROOT" &>/dev/null; then sudo losetup -d "$LOOPROOT"; fi
    set -e
}
trap cleanup EXIT

# === Step 0: Build Nix outputs ===
log_step "0/8" "Building Nix outputs"
KERNEL_BIN="$(nix build --impure .#kernel-repack --print-out-paths)/kernel.bin"
BOOTLOADER_DIR="./bootloader"
RAW_ROOTFS_IMG="$(nix build --impure .#raw-rootfs --print-out-paths)/nixos.img"
log_info "Kernel: $KERNEL_BIN"
log_info "Bootloader dir: $BOOTLOADER_DIR"
log_info "Raw rootfs: $RAW_ROOTFS_IMG"

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

# === Step 6: Format partitions ===
log_step "6/8" "Format partitions"
sudo mkfs.ext4 -q "${LOOPDEV}p1"
sudo dd if="$KERNEL_BIN" of="${LOOPDEV}p2" bs=1M conv=fsync status=progress
sudo mkfs.ext2 -q "${LOOPDEV}p3"
sudo mkfs.ext4 -q "${LOOPDEV}p4"

# === Step 7: Populate bootloader partition ===
log_step "7/8" "Populate bootloader partition"
sudo mount "${LOOPDEV}p3" "$WORKDIR/mnt_bootloader"
total_bytes=$(sudo du -sb "$BOOTLOADER_DIR" | cut -f1)
(cd "$BOOTLOADER_DIR" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_bootloader" && sudo tar xf -)
sudo umount "$WORKDIR/mnt_bootloader"

# === Step 8: Populate rootfs partition ===
log_step "8/8" "Populate rootfs partition"
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
sudo mount "${LOOPDEV}p4" "$WORKDIR/mnt_rootfs"
total_bytes=$(sudo du -sb "$WORKDIR/mnt_src_rootfs" | cut -f1)
(cd "$WORKDIR/mnt_src_rootfs" && sudo tar cf - .) | pv -s "$total_bytes" | (cd "$WORKDIR/mnt_rootfs" && sudo tar xf -)
sudo umount "$WORKDIR/mnt_rootfs" "$WORKDIR/mnt_src_rootfs"
sudo losetup -d "$LOOPROOT"
LOOPROOT=""

sudo losetup -d "$LOOPDEV"
LOOPDEV=""

log_info "✅ Final image created at: $IMAGE"

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