#!/usr/bin/env bash

# --- Build Configuration Variables ---

# Initialize configuration with default values
init_config() {
  # Project paths
  PROJECT_ROOT="$(pwd)"
  SHIM_FILE="$PROJECT_ROOT/data/shim.bin"
  RECOVERY_FILE="$PROJECT_ROOT/data/recovery.bin"
  KERNEL_FILE="$PROJECT_ROOT/data/kernel.bin"
  BOOTLOADER_DIR="$PROJECT_ROOT/bootloader"
  OUTPUT_PATH="$PROJECT_ROOT/shimboot_nixos.bin"
  WIFI_CREDENTIALS_FILE="$PROJECT_ROOT/wifi-credentials.json"
  WIFI_CREDENTIALS_EXAMPLE="$PROJECT_ROOT/wifi-credentials.json.example"
  
  # Partition sizes (in MB)
  STATE_PART_SIZE_MB=1
  KERNEL_PART_SIZE_MB=32
  BOOTLOADER_PART_SIZE_MB=32
  
  # Mount points
  SHIM_ROOTFS_MOUNT=""
  RECOVERY_ROOTFS_MOUNT=""
  NIXOS_SOURCE_MOUNT="/tmp/nixos_source_mount"
  BOOTLOADER_MOUNT="/tmp/shim_bootloader"
  ROOTFS_MOUNT="/tmp/new_rootfs"
  
  # Temporary directories
  TMP_DIR=""
  FIRMWARE_DEST_PATH=""
  MODPROBE_DEST_PATH=""
  KMOD_DEST_PATH=""
  
  # Loop devices
  IMAGE_LOOP=""
  SHIM_LOOP=""
  RECOVERY_LOOP=""
  NIXOS_LOOP=""
  
  # Build options
  USE_RECOVERY=false
  LOGFILE="build-final-image.log"
  
  # Systemd configuration
  SYSTEMD_VERSION_LOCK="257.6"  # Lock to systemd version 257.6 for stability
  SYSTEMD_REQUIRE_PATCHED=true  # Fail if no patched systemd is found
  SYSTEMD_BINARY_PATH="/nix/store/31v77wh2wsmn44sqayd4f34rxh94d459-systemd-257.6/lib/systemd/systemd"  # Use the working systemd binary
  
  # Required commands
  REQUIRED_COMMANDS="nix cgpt binwalk nixos-generate jq hexdump strings fdisk tar gunzip git"
  
  # Required files
  REQUIRED_FILES="$SHIM_FILE $BOOTLOADER_DIR"
}

# Update configuration based on command line arguments
update_config_from_args() {
  # This function can be extended to parse command line arguments
  # and update configuration variables accordingly
  :
}

# Print current configuration
print_config() {
  print_debug "Project root: $PROJECT_ROOT"
  print_debug "Shim file: $SHIM_FILE"
  print_debug "Recovery file: $RECOVERY_FILE"
  print_debug "Kernel file: $KERNEL_FILE"
  print_debug "Bootloader dir: $BOOTLOADER_DIR"
  print_debug "Output path: $OUTPUT_PATH"
  print_debug "WiFi credentials file: $WIFI_CREDENTIALS_FILE"
  print_debug "WiFi credentials example: $WIFI_CREDENTIALS_EXAMPLE"
  print_debug "Systemd version lock: ${SYSTEMD_VERSION_LOCK:-"none"}"
  print_debug "Require patched systemd: $SYSTEMD_REQUIRE_PATCHED"
  print_debug "Systemd binary path: ${SYSTEMD_BINARY_PATH:-"auto-detect"}"
}