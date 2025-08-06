#!/usr/bin/env bash

# --- Cleanup and Error Handling Functions ---

# Cleanup all resources used during the build process
cleanup_all() {
  print_info "Cleaning up..."
  
  # Cleanup sudo keepalive process
  cleanup_sudo
  
  # Unmount all mount points
  unmount_all
  
  # Detach all loop devices
  detach_all_loop_devices
  
  # Remove temporary directories
  remove_temp_dirs
  
  # Log warnings and errors
  log_warnings_and_errors "$LOGFILE"
  
  print_debug "Cleanup complete"
}

# Unmount all mount points used during the build process
unmount_all() {
  for mount_point in "$ROOTFS_MOUNT" "$BOOTLOADER_MOUNT" "$NIXOS_SOURCE_MOUNT" "$SHIM_ROOTFS_MOUNT" "$RECOVERY_ROOTFS_MOUNT"; do
    unmount_if_mounted "$mount_point"
  done
}

# Detach all loop devices used during the build process
detach_all_loop_devices() {
  detach_loop_device "$NIXOS_LOOP"
  detach_loop_device "$RECOVERY_LOOP"
  detach_loop_device "$SHIM_LOOP"
  detach_loop_device "$IMAGE_LOOP"
}

# Remove all temporary directories created during the build process
remove_temp_dirs() {
  remove_temp_dir "$TMP_DIR"
  remove_temp_dir "$SHIM_ROOTFS_MOUNT"
  remove_temp_dir "$RECOVERY_ROOTFS_MOUNT"
}

# Set up cleanup traps for graceful exit on script termination
setup_cleanup_traps() {
  # Set trap for normal exit
  trap 'cleanup_all' EXIT
  
  # Set trap for interruption
  trap 'print_error "Script interrupted by user"; cleanup_all; exit 130' INT
  
  # Set trap for termination
  trap 'print_error "Script terminated"; cleanup_all; exit 143' TERM
}

# Cleanup specific to extract-drivers.sh script
cleanup_extract_drivers() {
  if [ -n "$MOUNT_POINT" ]; then
    unmount_if_mounted "$MOUNT_POINT"
    remove_temp_dir "$MOUNT_POINT"
  fi
  detach_loop_device "$LOOP_DEVICE"
}

# Setup cleanup traps for extract-drivers.sh
setup_extract_drivers_traps() {
  trap 'cleanup_extract_drivers' EXIT
  trap 'print_error "Script interrupted by user"; cleanup_extract_drivers; exit 130' INT
  trap 'print_error "Script terminated"; cleanup_extract_drivers; exit 143' TERM
}

# Cleanup specific to create-image.sh script
cleanup_create_image() {
  detach_loop_device "$IMAGE_LOOP"
}

# Setup cleanup traps for create-image.sh
setup_create_image_traps() {
  trap 'cleanup_create_image' EXIT
  trap 'print_error "Script interrupted by user"; cleanup_create_image; exit 130' INT
  trap 'print_error "Script terminated"; cleanup_create_image; exit 143' TERM
}

# Handle errors during the build process
handle_error() {
  local exit_code=$?
  local line_number=$1
  print_error "Error on line $line_number: Command exited with status $exit_code"
  cleanup_all
  exit $exit_code
}

# Enable error handling with line numbers
enable_error_handling() {
  set -e
  set -o pipefail
  
  # Set up error trap with line number
  trap 'handle_error $LINENO' ERR
}

# Disable error handling (useful for sections where errors are expected)
disable_error_handling() {
  set +e
  set +o pipefail
  
  # Remove error trap
  trap - ERR
}