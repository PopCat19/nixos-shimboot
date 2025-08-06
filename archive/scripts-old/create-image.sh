#!/usr/bin/env bash

# Source all library modules
source "$(dirname "$0")/lib/common.sh"
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/prerequisites.sh"
source "$(dirname "$0")/lib/assemble.sh"
source "$(dirname "$0")/lib/cleanup.sh"

# Enable error handling
enable_error_handling

# --- Main Logic ---

# Check if correct number of arguments provided
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <output_path> <kernel_path> <initramfs_dir> <rootfs_dir>"
  exit 1
fi

# Initialize configuration
init_config

# Set up cleanup traps
setup_create_image_traps

# Check if running as root
check_root

# Set paths from arguments
OUTPUT_PATH="$(realpath -m "${1}")"
KERNEL_PATH="$(realpath -m "${2}")"
INITRAMFS_DIR="$(realpath -m "${3}")"
ROOTFS_DIR="$(realpath -m "${4}")"

print_info "Creating disk image"

# Calculate sizes
ROOTFS_SIZE_MB="$(du -sm "$ROOTFS_DIR" | cut -f 1)"
# Make rootfs partition 20% larger than its contents, plus a little extra
ROOTFS_PART_SIZE_MB=$((ROOTFS_SIZE_MB * 12 / 10 + 100))
# Create a 32MB bootloader partition
BOOTLOADER_PART_SIZE_MB=32

# Calculate total size
TOTAL_SIZE=$((STATE_PART_SIZE_MB + KERNEL_PART_SIZE_MB + BOOTLOADER_PART_SIZE_MB + ROOTFS_PART_SIZE_MB))

# Create disk image
create_disk_image "$TOTAL_SIZE"

# Setup loop device
setup_image_loop_device

# Create partitions on the disk image
print_info "Creating partitions on the disk image"
format_partitions

# Copy data into the image
print_info "Copying data into the image"

# Mount and write to bootloader rootfs
print_info "Copying bootloader..."
sudo mkdir -p "$BOOTLOADER_MOUNT"
sudo mount "${IMAGE_LOOP}p3" "$BOOTLOADER_MOUNT"
sudo cp -ar "$INITRAMFS_DIR"/* "$BOOTLOADER_MOUNT/"
unmount_if_mounted "$BOOTLOADER_MOUNT"

# Write rootfs to image
print_info "Copying rootfs... (this may take a moment)"
sudo mkdir -p "$ROOTFS_MOUNT"
sudo mount "${IMAGE_LOOP}p4" "$ROOTFS_MOUNT"
sudo cp -ar "$ROOTFS_DIR"/. "$ROOTFS_MOUNT"/
unmount_if_mounted "$ROOTFS_MOUNT"

# Fix ownership of output file
fix_output_ownership

print_info "Done. Final image is at: $OUTPUT_PATH"
