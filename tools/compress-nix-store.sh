#!/usr/bin/env bash

# compress-nix-store.sh
#
# Purpose: Compress /nix/store with squashfs to reduce disk usage
#
# This module:
# - Creates squashfs archive of /nix/store with zstd compression
# - Replaces original store with compressed read-only version
# - Reports size reduction statistics

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh"

usage() {
	echo "Usage: $0 <rootfs-directory>"
	echo ""
	echo "Compress /nix/store with squashfs to reduce disk usage."
	echo ""
	echo "Arguments:"
	echo "  rootfs-directory    Path to rootfs containing /nix/store"
	echo ""
	echo "Example:"
	echo "  $0 ./work/dedede/rootfs"
	exit 0
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		;;
	-*)
		log_error "Unknown option: $1"
		usage
		exit 1
		;;
	*)
		break
		;;
	esac
	shift
done

ROOTFS_DIR="${1:-}"

if [ ! -d "$ROOTFS_DIR/nix/store" ]; then
	log_error "$ROOTFS_DIR/nix/store not found"
	exit 1
fi

log_info "Compressing /nix/store with squashfs..."

# Calculate original size for reporting
ORIGINAL_SIZE=$(du -sm "$ROOTFS_DIR/nix/store" | cut -f1)
log_info "Original /nix/store size: ${ORIGINAL_SIZE} MB"

# Create target directory
TARGET_DIR="$ROOTFS_DIR/nix/.ro-store"
mkdir -p "$TARGET_DIR"

# Create temporary directory outside rootfs for compression
TEMP_DIR="$(mktemp -d -p /tmp)"
SQUASHFS_FILE="$TEMP_DIR/store.squashfs"

# Create squashfs with zstd compression in temporary location
log_info "Creating squashfs with zstd compression..."
mksquashfs "$ROOTFS_DIR/nix/store" \
	"$SQUASHFS_FILE" \
	-comp zstd \
	-Xcompression-level 15 \
	-noappend

COMPRESSED_SIZE=$(du -sm "$SQUASHFS_FILE" | cut -f1)
REDUCTION=$((ORIGINAL_SIZE - COMPRESSED_SIZE))
REDUCTION_PCT=$((REDUCTION * 100 / ORIGINAL_SIZE))

log_info "squashfs created: ${COMPRESSED_SIZE} MB (reduced by ${REDUCTION} MB, ${REDUCTION_PCT}%)"

# Remove original store FIRST to free up space
log_info "Removing original /nix/store to free space..."
rm -rf "$ROOTFS_DIR/nix/store"
mkdir -p "$ROOTFS_DIR/nix/store"

# Now move the compressed file (should have enough space now)
log_info "Moving compressed file to target location..."
mv "$SQUASHFS_FILE" "$TARGET_DIR/store.squashfs"

# Cleanup temporary directory
rm -rf "$TEMP_DIR"

log_success "/nix/store compressed successfully"
log_info "Final compressed size: ${COMPRESSED_SIZE} MB (was ${ORIGINAL_SIZE} MB)"
