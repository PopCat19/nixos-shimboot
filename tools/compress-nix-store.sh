#!/usr/bin/env bash
set -euo pipefail

ROOTFS_DIR="$1"

if [ ! -d "$ROOTFS_DIR/nix/store" ]; then
  echo "Error: $ROOTFS_DIR/nix/store not found"
  exit 1
fi

echo "Compressing /nix/store with squashfs..."

# Calculate original size for reporting
ORIGINAL_SIZE=$(du -sm "$ROOTFS_DIR/nix/store" | cut -f1)
echo "Original /nix/store size: ${ORIGINAL_SIZE} MB"

# Create target directory
TARGET_DIR="$ROOTFS_DIR/nix/.ro-store"
mkdir -p "$TARGET_DIR"

# Create temporary directory outside rootfs for compression
TEMP_DIR="$(mktemp -d -p /tmp)"
SQUASHFS_FILE="$TEMP_DIR/store.squashfs"

# Create squashfs with zstd compression in temporary location
echo "Creating squashfs with zstd compression..."
mksquashfs "$ROOTFS_DIR/nix/store" \
  "$SQUASHFS_FILE" \
  -comp zstd \
  -Xcompression-level 15 \
  -noappend

COMPRESSED_SIZE=$(du -sm "$SQUASHFS_FILE" | cut -f1)
REDUCTION=$((ORIGINAL_SIZE - COMPRESSED_SIZE))
REDUCTION_PCT=$((REDUCTION * 100 / ORIGINAL_SIZE))

echo "squashfs created: ${COMPRESSED_SIZE} MB (reduced by ${REDUCTION} MB, ${REDUCTION_PCT}%)"

# Remove original store FIRST to free up space
echo "Removing original /nix/store to free space..."
rm -rf "$ROOTFS_DIR/nix/store"
mkdir -p "$ROOTFS_DIR/nix/store"

# Now move the compressed file (should have enough space now)
echo "Moving compressed file to target location..."
mv "$SQUASHFS_FILE" "$TARGET_DIR/store.squashfs"

# Cleanup temporary directory
rm -rf "$TEMP_DIR"

echo "✓ /nix/store compressed successfully"
echo "Final compressed size: ${COMPRESSED_SIZE} MB (was ${ORIGINAL_SIZE} MB)"