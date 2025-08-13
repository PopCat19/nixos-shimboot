#!/usr/bin/env bash
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
if [ -f "$WORKDIR/rootfs/sbin/init" ]; then
    echo "✅ Found /sbin/init"
elif [ -f "$WORKDIR/rootfs/init" ]; then
    echo "✅ Found /init"
else
    echo "❌ No init found at /sbin/init or /init"
fi