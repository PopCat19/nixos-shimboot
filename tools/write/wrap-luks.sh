#!/usr/bin/env bash
# wrap-luks.sh
#
# Purpose: Wrap a shimboot image's rootfs partition in a LUKS2 container
# Dependencies: cryptsetup, sgdisk, coreutils
#
# This script:
# - Extracts the rootfs partition from a LUKS-capable shimboot image
# - Creates a LUKS2 container and copies the rootfs into it
# - Replaces the rootfs partition with the encrypted container
# - Requires sudo (dm-crypt / loop devices)
#
# Usage:
#   sudo ./wrap-luks.sh --image /path/to/shimboot.img [--password pass]

set -euo pipefail

IMAGE=""
PASSWORD="${LUKS_PASSWORD:-shimboot}"
ROOTFS_PART=5
LOOPDEV=""

cleanup() {
  if [ -n "${LOOPDEV:-}" ] && losetup "$LOOPDEV" &>/dev/null 2>&1; then
    sudo losetup -d "$LOOPDEV" 2>/dev/null || true
  fi
  if [ -e /dev/mapper/rootfs_wrap ]; then
    sudo cryptsetup close rootfs_wrap 2>/dev/null || true
  fi
}
trap cleanup EXIT

while [ $# -gt 0 ]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --password) PASSWORD="$2"; shift 2 ;;
    --partition) ROOTFS_PART="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --image <shimboot.img> [--password <pass>] [--partition <num>]"
      echo "  Wraps the rootfs partition in a LUKS2 encrypted container."
      echo "  Default partition: 5 (shimboot_rootfs:nixos)"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
  echo "ERROR: --image is required and must exist" >&2
  exit 1
fi

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: Must run as root (needs losetup + cryptsetup)" >&2
  exit 1
fi

echo "=== LUKS2: wrapping rootfs partition $ROOTFS_PART ==="

# Get partition info
ROOTFS_START=$(sgdisk -i "$ROOTFS_PART" "$IMAGE" | grep "First sector" | awk '{print $3}')
ROOTFS_SECTORS=$(sgdisk -i "$ROOTFS_PART" "$IMAGE" | grep "Partition size" | awk '{print $3}')
SEC_SIZE=$(sgdisk -i "$ROOTFS_PART" "$IMAGE" | grep "Sector size" | awk '{print $4}' | sed 's/[^0-9]//g')
SEC_SIZE="${SEC_SIZE:-512}"

if [ -z "$ROOTFS_START" ] || [ -z "$ROOTFS_SECTORS" ]; then
  echo "ERROR: Could not find partition $ROOTFS_PART" >&2
  exit 1
fi

echo "  Partition $ROOTFS_PART: start=$ROOTFS_START sectors=$ROOTFS_SECTORS"

# Extract unencrypted rootfs
echo "  Extracting unencrypted rootfs..."
dd if="$IMAGE" of=/tmp/rootfs_plain.img bs="$SEC_SIZE" skip="$ROOTFS_START" count="$ROOTFS_SECTORS" status=none

ROOTFS_SIZE=$(stat -c%s /tmp/rootfs_plain.img)
LUKS_SIZE=$(( ROOTFS_SIZE + 16777216 ))  # +16MiB for LUKS2 header

# Create LUKS2 container
echo "  Creating LUKS2 container (${LUKS_SIZE} bytes)..."
truncate -s "$LUKS_SIZE" /tmp/rootfs_luks.img
echo -n "$PASSWORD" | cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 \
  --pbkdf-memory 131072 --iter-time 2000 /tmp/rootfs_luks.img -q

# Open and copy
echo "  Opening LUKS2 container..."
echo -n "$PASSWORD" | cryptsetup open --type luks2 /tmp/rootfs_luks.img rootfs_wrap

echo "  Copying rootfs into encrypted container..."
dd if=/tmp/rootfs_plain.img of=/dev/mapper/rootfs_wrap bs=1M conv=fsync status=progress

cryptsetup close rootfs_wrap

# Verify LUKS container fits in partition
LUKS_SECTORS=$(( (LUKS_SIZE + SEC_SIZE - 1) / SEC_SIZE ))
if [ "$LUKS_SECTORS" -gt "$ROOTFS_SECTORS" ]; then
  echo "ERROR: LUKS container ($LUKS_SECTORS sectors) exceeds partition ($ROOTFS_SECTORS sectors)" >&2
  echo "  Image too tight. Rebuild with larger rootfs partition." >&2
  exit 1
fi

# Write LUKS container back to image
echo "  Writing LUKS container to image..."
dd if=/tmp/rootfs_luks.img of="$IMAGE" bs="$SEC_SIZE" seek="$ROOTFS_START" conv=notrunc status=none

rm -f /tmp/rootfs_plain.img /tmp/rootfs_luks.img

echo "=== LUKS2 wrapping complete ==="
echo "  Default passphrase: $PASSWORD"
echo "  Change on first boot: cryptsetup luksChangeKey /dev/sda5"
