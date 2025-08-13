#!/usr/bin/env bash
set -euo pipefail

SYSTEM="x86_64-linux"
WORKDIR="$(pwd)/work"
IMAGE="$WORKDIR/shimboot.img"
ROOTFS_NAME="${ROOTFS_NAME:-nixos}"
INSPECT_AFTER="${1:-}"

# Ensure clean workspace
if [ -d "$WORKDIR" ]; then
    echo "[INIT] Cleaning up old work directory..."
    sudo rm -rf "$WORKDIR"
fi
mkdir -p "$WORKDIR" "$WORKDIR/mnt_src_rootfs" "$WORKDIR/mnt_bootloader" "$WORKDIR/mnt_rootfs"

# Track loop devices for cleanup
LOOPDEV=""
LOOPROOT=""

cleanup() {
    echo "[CLEANUP] Unmounting and detaching loop devices..."
    set +e
    if mountpoint -q "$WORKDIR/mnt_rootfs"; then sudo umount "$WORKDIR/mnt_rootfs"; fi
    if mountpoint -q "$WORKDIR/mnt_bootloader"; then sudo umount "$WORKDIR/mnt_bootloader"; fi
    if mountpoint -q "$WORKDIR/mnt_src_rootfs"; then sudo umount "$WORKDIR/mnt_src_rootfs"; fi
    if [ -n "$LOOPDEV" ] && losetup "$LOOPDEV" &>/dev/null; then sudo losetup -d "$LOOPDEV"; fi
    if [ -n "$LOOPROOT" ] && losetup "$LOOPROOT" &>/dev/null; then sudo losetup -d "$LOOPROOT"; fi
    set -e
}
trap cleanup EXIT

# Nix build outputs (Steps 1–4)
KERNEL_BIN="$(nix build --impure .#kernel-repack --print-out-paths)/kernel.bin"
BOOTLOADER_DIR="./bootloader"
RAW_ROOTFS_IMG="$(nix build --impure .#raw-rootfs --print-out-paths)/nixos.img"

# Partition sizes (MB)
STATEFUL_MB=1
KERNEL_MB=32
BOOTLOADER_MB=20

mkdir -p "$WORKDIR" "$WORKDIR/mnt_src_rootfs" "$WORKDIR/mnt_bootloader" "$WORKDIR/mnt_rootfs"

echo "[1/8] Copy raw rootfs image..."
cp "$RAW_ROOTFS_IMG" "$WORKDIR/rootfs.img"

echo "[2/8] Calculate rootfs size..."
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
ROOTFS_SIZE_MB=$(sudo du -sm "$WORKDIR/mnt_src_rootfs" | cut -f1)
sudo umount "$WORKDIR/mnt_src_rootfs"
sudo losetup -d "$LOOPROOT"
LOOPROOT=""

ROOTFS_PART_SIZE=$(( (ROOTFS_SIZE_MB * 12 / 10) + 5 ))
TOTAL_SIZE_MB=$((STATEFUL_MB + KERNEL_MB + BOOTLOADER_MB + ROOTFS_PART_SIZE))

echo "[3/8] Create empty $TOTAL_SIZE_MB MB image..."
fallocate -l ${TOTAL_SIZE_MB}M "$IMAGE"

echo "[4/8] Partition image..."
parted --script "$IMAGE" \
  mklabel gpt \
  mkpart stateful ext4 1MiB $((1+STATEFUL_MB))MiB \
  name 1 STATE \
  mkpart kernel  $((1+STATEFUL_MB))MiB $((1+STATEFUL_MB+KERNEL_MB))MiB \
  name 2 KERN-A \
  type 2 FE3A2A5D-4F32-41A7-B725-ACCC3285A309 \
  mkpart bootloader ext2 $((1+STATEFUL_MB+KERNEL_MB))MiB $((1+STATEFUL_MB+KERNEL_MB+BOOTLOADER_MB))MiB \
  name 3 SHIMBOOT \
  type 3 3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC \
  mkpart rootfs ext4 $((1+STATEFUL_MB+KERNEL_MB+BOOTLOADER_MB))MiB 100% \
  name 4 "shimboot_rootfs:${ROOTFS_NAME}"

echo "[5/8] Setup loop device..."
LOOPDEV=$(sudo losetup --show -fP "$IMAGE")

echo "[6/8] Format partitions..."
sudo mkfs.ext4 -q "${LOOPDEV}p1"
sudo dd if="$KERNEL_BIN" of="${LOOPDEV}p2" bs=1M conv=fsync status=progress
sudo mkfs.ext2 -q "${LOOPDEV}p3"
sudo mkfs.ext4 -q "${LOOPDEV}p4"

echo "[7/8] Populate bootloader partition..."
sudo mount "${LOOPDEV}p3" "$WORKDIR/mnt_bootloader"
sudo cp -a "$BOOTLOADER_DIR"/* "$WORKDIR/mnt_bootloader/"
sudo umount "$WORKDIR/mnt_bootloader"

echo "[8/8] Populate rootfs partition..."
LOOPROOT=$(sudo losetup --show -fP "$WORKDIR/rootfs.img")
sudo mount "${LOOPROOT}p1" "$WORKDIR/mnt_src_rootfs"
sudo mount "${LOOPDEV}p4" "$WORKDIR/mnt_rootfs"
sudo cp -a "$WORKDIR/mnt_src_rootfs"/* "$WORKDIR/mnt_rootfs/"
sudo umount "$WORKDIR/mnt_rootfs" "$WORKDIR/mnt_src_rootfs"
sudo losetup -d "$LOOPROOT"
LOOPROOT=""

sudo losetup -d "$LOOPDEV"
LOOPDEV=""

echo "✅ Final image created at: $IMAGE"

# Optional inspection
if [ "$INSPECT_AFTER" = "--inspect" ]; then
    echo
    echo "=== Partition Table ==="
    sudo partx -o NR,START,END,SIZE,TYPE,NAME,UUID -g --show "$IMAGE" || true
    echo
    echo "[INFO] Mounting rootfs to check init..."
    LOOPDEV=$(sudo losetup --show -fP "$IMAGE")
    mkdir -p "$WORKDIR/inspect_rootfs"
    sudo mount "${LOOPDEV}p4" "$WORKDIR/inspect_rootfs"
    sudo ls -l "$WORKDIR/inspect_rootfs"
    if [ -f "$WORKDIR/inspect_rootfs/sbin/init" ] || [ -f "$WORKDIR/inspect_rootfs/init" ]; then
        echo "✅ Init found"
    else
        echo "❌ Init missing"
    fi
    sudo umount "$WORKDIR/inspect_rootfs"
    sudo losetup -d "$LOOPDEV"
fi