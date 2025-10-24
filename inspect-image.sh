#!/usr/bin/env bash

# Inspect Image Script
#
# Purpose: Inspect shimboot image structure and verify rootfs contents
# Dependencies: sudo, losetup, mount, umount, lsblk, gdisk, blkid, file
# Related: assemble-final.sh, write-shimboot-image.sh
#
# This script mounts the shimboot image read-only and displays partition table,
# filesystem details, and verifies the presence of init system.
#
# Usage:
#   sudo ./inspect-image.sh work/shimboot.img

set -euo pipefail

IMAGE="${1:-work/shimboot.img}"
WORKDIR="$(mktemp -d)"
LOOPDEV=""

cleanup() {
	echo "[CLEANUP] Unmounting and detaching..."
	set +e
	if mountpoint -q "$WORKDIR/rootfs"; then sudo umount "$WORKDIR/rootfs"; fi
	if [ -n "$LOOPDEV" ] && losetup "$LOOPDEV" &>/dev/null; then sudo losetup -d "$LOOPDEV"; fi
	rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "=== Partition Table for $IMAGE ==="
sudo partx -o NR,START,END,SIZE,TYPE,NAME,UUID -g --show "$IMAGE" || true
echo

echo "=== Detailed GPT Info ==="
sudo gdisk -l "$IMAGE" || true
echo

echo "[INFO] Setting up loop device..."
LOOPDEV=$(sudo losetup --show -fP "$IMAGE")

echo "[INFO] Mounting rootfs partition..."
mkdir -p "$WORKDIR/rootfs"
sudo mount "${LOOPDEV}p4" "$WORKDIR/rootfs"

echo "=== Top-level rootfs structure ==="
sudo ls -l "$WORKDIR/rootfs"

echo
echo "[INFO] Filesystem label for rootfs partition (should be: ${ROOTFS_NAME:-nixos})"
sudo blkid "${LOOPDEV}p4" || true

echo
if [ -f "$WORKDIR/rootfs/sbin/init" ]; then
	echo "✅ Found /sbin/init"
elif [ -f "$WORKDIR/rootfs/init" ]; then
	echo "✅ Found /init"
else
	echo "❌ No init found at /sbin/init or /init"
fi
