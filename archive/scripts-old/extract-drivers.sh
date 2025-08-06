#!/usr/bin/env bash

# Source all library modules
source "$(dirname "$0")/lib/common.sh"
source "$(dirname "$0")/lib/config.sh"
source "$(dirname "$0")/lib/prerequisites.sh"
source "$(dirname "$0")/lib/harvest.sh"
source "$(dirname "$0")/lib/cleanup.sh"

# Enable error handling
enable_error_handling

# --- Main Logic ---

# Check if correct number of arguments provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <path/to/shim.bin> <output_directory>"
  exit 1
fi

# Initialize configuration with custom paths
init_config
SHIM_FILE="$1"
OUTPUT_DIR="$2"

# Set up cleanup traps
setup_extract_drivers_traps

# Check prerequisites
print_info "Checking prerequisites for driver extraction..."
check_commands "cgpt losetup mount"

print_info "--- Performing impure driver extraction ---"

# Create a temporary directory for mounting
MOUNT_POINT=$(create_temp_dir "extract_drivers_mount")

# Find the partition info
print_debug "Finding ROOT-A partition in shim image..."
read -r part_start part_size _ < <(cgpt show -i 3 "$SHIM_FILE" | awk '$4 == "Label:" && $5 == "\"ROOT-A\""')

if [ -z "$part_start" ] || [ -z "$part_size" ]; then
  print_error "Could not find ROOT-A partition in shim image"
  exit 1
fi

echo "Found ROOT-A at sector $part_start, size $part_size sectors."

# Setup loop device and mount
print_debug "Setting up loop device for shim partition..."
LOOP_DEVICE=$(create_loop_device_with_offset "$SHIM_FILE" "$part_start" "$part_size")
print_debug "Mounting partition..."
sudo mount -o ro "$LOOP_DEVICE" "$MOUNT_POINT"

echo "Mounted partition on $MOUNT_POINT."

# Create the final output directory
mkdir -p "$OUTPUT_DIR"/lib

# Copy the sacred artifacts
echo "Copying /lib/firmware and /lib/modules..."
sudo cp -r "$MOUNT_POINT"/lib/firmware "$OUTPUT_DIR"/lib/
sudo cp -r "$MOUNT_POINT"/lib/modules "$OUTPUT_DIR"/lib/

echo "--- Extraction complete. Output at: $OUTPUT_DIR ---"

# Helper function to create loop device with offset and size
create_loop_device_with_offset() {
  local image_path="$1"
  local offset="$2"
  local size="$3"
  
  local loop_device
  loop_device=$(sudo losetup -f)
  sudo losetup -o $(($offset * 512)) --sizelimit $(($size * 512)) "$loop_device" "$image_path"
  echo "$loop_device"
}
