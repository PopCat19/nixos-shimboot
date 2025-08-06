#!/usr/bin/env bash

# --- Image Assembly Functions ---

# Create disk image with specified size
create_disk_image() {
  local total_size_mb="$1"
  
  print_info "Creating ${total_size_mb}MB disk image"
  rm -f "$OUTPUT_PATH"
  
  # Ensure the size is a valid integer
  if ! [[ "$total_size_mb" =~ ^[0-9]+$ ]]; then
    print_error "Invalid size value: $total_size_mb"
    exit 1
  fi
  
  # Use dd instead of fallocate for better compatibility
  print_debug "Creating disk image with dd: bs=1M count=$total_size_mb"
  dd if=/dev/zero of="$OUTPUT_PATH" bs=1M count="$total_size_mb" status=progress
}

# Partition disk image with ChromeOS-style partition table
partition_disk_image() {
  print_info "Partitioning disk image"
  (
    echo g
    echo n
    echo
    echo
    echo +1M
    echo n
    echo
    echo
    echo +32M
    echo n
    echo
    echo
    echo "+${BOOTLOADER_PART_SIZE_MB}M"
    echo n
    echo
    echo
    echo
    echo w
  ) | sudo fdisk "$OUTPUT_PATH" >/dev/null
  
  sudo cgpt add -i 1 -t data -l "STATE" "$OUTPUT_PATH"
  sudo cgpt add -i 2 -t kernel -l "kernel" -S 1 -T 5 -P 10 "$OUTPUT_PATH"
  sudo cgpt add -i 3 -t rootfs -l "BOOT" "$OUTPUT_PATH"
  sudo cgpt add -i 4 -t data -l "shimboot_rootfs:nixos" "$OUTPUT_PATH"
  
  print_debug "Verifying partition table:"
  sudo fdisk -l "$OUTPUT_PATH"
}

# Create loop device for final image
setup_image_loop_device() {
  print_info "Creating loop device for final image"
  IMAGE_LOOP=$(create_loop_device "$OUTPUT_PATH")
  print_debug "Assigned final image loop device: $IMAGE_LOOP"
}

# Format partitions
format_partitions() {
  print_info "Formatting partitions"
  sudo mkfs.ext4 -L STATE "${IMAGE_LOOP}p1" >/dev/null
  sudo dd if="$KERNEL_FILE" of="${IMAGE_LOOP}p2" bs=1M oflag=sync status=progress
  sudo mkfs.ext2 -L BOOT "${IMAGE_LOOP}p3" >/dev/null
  # Use ChromeOS-compatible ext4 options (same as original shimboot)
  sudo mkfs.ext4 -L ROOTFS -O ^has_journal,^metadata_csum,^64bit -F "${IMAGE_LOOP}p4" >/dev/null
}

# Copy bootloader to BOOT partition
copy_bootloader() {
  print_info "Copying bootloader..."
  sudo mkdir -p "$BOOTLOADER_MOUNT"
  sudo mount "${IMAGE_LOOP}p3" "$BOOTLOADER_MOUNT"
  sudo cp -ar "$TMP_DIR/initramfs_extracted"/* "$BOOTLOADER_MOUNT/"
  unmount_if_mounted "$BOOTLOADER_MOUNT"
}

# Copy NixOS rootfs to ROOTFS partition
copy_rootfs() {
  print_info "Copying NixOS rootfs... (this may take a while)"
  sudo mkdir -p "$ROOTFS_MOUNT"
  sudo mount "${IMAGE_LOOP}p4" "$ROOTFS_MOUNT"
  print_debug "Copying rootfs from source image to partition..."
  sudo cp -ar "$NIXOS_SOURCE_MOUNT"/* "$ROOTFS_MOUNT/"
  print_debug "Rootfs copy complete"
}

# Verify that a systemd binary is patched with our mount_nofollow patch
verify_systemd_patch() {
  local systemd_binary="$1"
  
  print_debug "Verifying systemd patch in $systemd_binary"
  
  # Check if the binary exists
  if [ ! -f "$systemd_binary" ]; then
    print_debug "Systemd binary does not exist: $systemd_binary"
    return 1
  fi
  
  # Check if the binary contains the mount_nofollow function
  if ! sudo strings "$systemd_binary" 2>/dev/null | grep -q "mount_nofollow"; then
    print_debug "mount_nofollow function not found in systemd binary"
    return 1
  fi
  
  # Check if the binary contains the expected simplified mount call
  # The patch replaces the complex mount_fd call with a simple mount call
  if sudo strings "$systemd_binary" 2>/dev/null | grep -q "mount.*source.*target.*filesystemtype.*mountflags.*data"; then
    print_debug "Found simplified mount call in systemd binary"
    return 0
  fi
  
  # Alternative check: look for RET_NERRNO macro which is used in the patch
  if sudo strings "$systemd_binary" 2>/dev/null | grep -q "RET_NERRNO"; then
    print_debug "Found RET_NERRNO macro in systemd binary"
    return 0
  fi
  
  # If we get here, the binary contains mount_nofollow but doesn't appear to be patched
  print_debug "Systemd binary contains mount_nofollow but doesn't appear to be patched"
  return 1
}

# Find the best patched systemd binary
find_patched_systemd() {
  print_debug "Searching for patched systemd binaries..."
  
  # If a manual path is specified, use it
  if [ -n "$SYSTEMD_BINARY_PATH" ]; then
    print_debug "Using manually specified systemd binary path: $SYSTEMD_BINARY_PATH"
    
    # Convert relative path to absolute path if needed
    local systemd_binary_path="$SYSTEMD_BINARY_PATH"
    if [[ "$systemd_binary_path" != /* ]]; then
      systemd_binary_path="${ROOTFS_MOUNT}/${systemd_binary_path}"
    fi
    
    # Check if the specified binary exists
    if [ -f "$systemd_binary_path" ]; then
      echo "$systemd_binary_path"
      return 0
    else
      print_error "Manually specified systemd binary not found: $systemd_binary_path"
      return 1
    fi
  fi
  
  # Find all systemd binaries
  local all_systemd_binaries
  all_systemd_binaries=$(sudo find "${ROOTFS_MOUNT}/nix/store" -path "*/lib/systemd/systemd" -type f | sort -r)
  
  local patched_binaries=()
  
  # Check each binary to see if it's patched
  for binary in $all_systemd_binaries; do
    if verify_systemd_patch "$binary"; then
      print_debug "Found patched systemd: $binary"
      
      # If version locking is enabled, check the version
      if [ -n "$SYSTEMD_VERSION_LOCK" ]; then
        local systemd_version
        systemd_version=$(sudo strings "$binary" 2>/dev/null | grep -o "systemd [0-9][0-9]*\(\.[0-9][0-9]*\)*" | head -1 | cut -d' ' -f2)
        print_debug "Systemd version: $systemd_version"
        
        if [ "$systemd_version" = "$SYSTEMD_VERSION_LOCK" ]; then
          print_debug "Found matching systemd version: $systemd_version"
          patched_binaries=("$binary")
          break
        else
          print_debug "Systemd version $systemd_version does not match required version $SYSTEMD_VERSION_LOCK"
        fi
      else
        # No version locking, add to list of candidates
        patched_binaries+=("$binary")
      fi
    fi
  done
  
  # Return the first (most recent) patched binary
  if [ ${#patched_binaries[@]} -gt 0 ]; then
    echo "${patched_binaries[0]}"
    return 0
  fi
  
  # No patched systemd found
  return 1
}

# Create systemd init symlink
create_systemd_symlink() {
  print_info "Creating systemd init symlink..."
  
  # Check if we require patched systemd
  if [ "$SYSTEMD_REQUIRE_PATCHED" = true ]; then
    # Try to find a patched systemd first
    local systemd_binary_path
    if systemd_binary_path=$(find_patched_systemd); then
      print_info "Using patched systemd binary"
    else
      print_error "No patched systemd binary found in the Nix store!"
      print_error "The build requires systemd to be patched with the mount_nofollow patch."
      if [ -n "$SYSTEMD_VERSION_LOCK" ]; then
        print_error "Required systemd version: $SYSTEMD_VERSION_LOCK"
      fi
      print_error "Please ensure the systemd package in your configuration includes the patch."
      print_debug "Available systemd binaries:"
      sudo find "${ROOTFS_MOUNT}/nix/store" -path "*/lib/systemd/systemd" -type f | head -5 | while read -r binary; do
        print_debug "  - $binary"
      done
      exit 1
    fi
  else
    # Find any systemd binary (patched or not)
    local systemd_binary_path
    systemd_binary_path=$(sudo find "${ROOTFS_MOUNT}/nix/store" -path "*/lib/systemd/systemd" -type f | head -n 1)
    
    if [ -z "$systemd_binary_path" ]; then
      print_error "No systemd binary found in the Nix store!"
      exit 1
    fi
    
    # Check if it's patched for informational purposes
    if verify_systemd_patch "$systemd_binary_path"; then
      print_info "Using patched systemd binary"
    else
      print_info "Using unpatched systemd binary (patch verification disabled)"
    fi
  fi
  
  # The path returned by find is absolute on the host. The symlink target must be absolute inside the new rootfs.
  local symlink_target
  symlink_target=${systemd_binary_path#"$ROOTFS_MOUNT"}
  
  print_debug "Found systemd binary at: $systemd_binary_path"
  print_debug "Creating symlink /init -> $symlink_target"
  
  # Create the symlink
  sudo ln -sf "$symlink_target" "${ROOTFS_MOUNT}/init"
  
  # Verify the symlink was created correctly
  if [ ! -L "${ROOTFS_MOUNT}/init" ]; then
    print_error "Failed to create systemd symlink"
    exit 1
  fi
  
  # Get the systemd version for logging
  local systemd_version
  systemd_version=$(sudo strings "$systemd_binary_path" | grep -o "systemd [0-9][0-9]*\(\.[0-9][0-9]*\)*" | head -1)
  print_info "Systemd symlink created successfully using $systemd_version"
}

# Inject harvested kernel modules into new rootfs
inject_kernel_modules() {
  print_info "Injecting harvested kernel modules into new rootfs..."
  if [ -d "$TMP_DIR/kernel_modules" ]; then
    # Ensure lib directory exists first
    sudo mkdir -p "${ROOTFS_MOUNT}/lib"
    # Follow original shimboot approach - completely replace modules
    sudo rm -rf "${ROOTFS_MOUNT}/lib/modules"
    sudo cp -ar "$TMP_DIR/kernel_modules" "${ROOTFS_MOUNT}/lib/modules"
    print_debug "Modules copied to ${ROOTFS_MOUNT}/lib/modules/"
    
    # Decompress kernel modules if necessary - like original shimboot
    print_info "Decompressing kernel modules if needed..."
    local compressed_files
    compressed_files=$(sudo find "${ROOTFS_MOUNT}/lib/modules" -name '*.gz' 2>/dev/null || true)
    if [ -n "$compressed_files" ]; then
      print_debug "Found compressed modules, decompressing..."
      echo "$compressed_files" | sudo xargs gunzip
      
      # Rebuild module dependencies
      local kernel_dir
      for kernel_dir in "${ROOTFS_MOUNT}/lib/modules/"*; do
        if [ -d "$kernel_dir" ]; then
          local version
          version="$(basename "$kernel_dir")"
          print_debug "Rebuilding module dependencies for kernel $version"
          sudo depmod -b "${ROOTFS_MOUNT}" "$version" 2>/dev/null || true
        fi
      done
    fi
  else
    print_error "Harvested kernel modules not found in temp directory. Skipping."
  fi
}

# Inject harvested firmware into new rootfs
inject_firmware() {
  print_info "Injecting harvested firmware into new rootfs..."
  if [ -d "$TMP_DIR/firmware" ]; then
    sudo mkdir -p "${ROOTFS_MOUNT}/lib/firmware"
    sudo cp -r --remove-destination "$TMP_DIR/firmware"/* "${ROOTFS_MOUNT}/lib/firmware/" 2>/dev/null || true
    print_debug "Firmware copied to ${ROOTFS_MOUNT}/lib/firmware/"
  else
    print_debug "No harvested firmware found, skipping."
  fi
}

# Inject modprobe configurations into new rootfs
inject_modprobe_configs() {
  if [ "$USE_RECOVERY" = true ] && [ -d "$TMP_DIR/modprobe.d" ]; then
    print_info "Injecting modprobe configurations into new rootfs..."
    sudo mkdir -p "${ROOTFS_MOUNT}/lib/modprobe.d" "${ROOTFS_MOUNT}/etc/modprobe.d"
    sudo cp -r "$TMP_DIR/modprobe.d"/* "${ROOTFS_MOUNT}/lib/modprobe.d/" 2>/dev/null || true
    sudo cp -r "$TMP_DIR/modprobe.d"/* "${ROOTFS_MOUNT}/etc/modprobe.d/" 2>/dev/null || true
    print_debug "Modprobe configurations copied"
  fi
}

# Create traditional symlinks for compatibility
create_traditional_symlinks() {
  print_debug "Manually creating traditional symlinks..."
  sudo mkdir -p "${ROOTFS_MOUNT}/sbin" "${ROOTFS_MOUNT}/usr/sbin"
  sudo ln -sf /init "${ROOTFS_MOUNT}/sbin/init"
  sudo ln -sf /init "${ROOTFS_MOUNT}/usr/sbin/init"
}

# Reset machine-id for golden image
reset_machine_id() {
  print_info "Resetting machine-id for golden image..."
  if [ -f "${ROOTFS_MOUNT}/etc/machine-id" ]; then
      sudo rm -f "${ROOTFS_MOUNT}/etc/machine-id"
      print_debug "Removed existing machine-id."
  fi
  # Create an empty file to ensure it's generated on first boot
  sudo touch "${ROOTFS_MOUNT}/etc/machine-id"
  print_debug "Ensured /etc/machine-id is ready for first-boot generation."
}

# Fix ownership of output file
fix_output_ownership() {
  print_debug "Fixing ownership of output file..."
  sudo chown "$(id -u):$(id -g)" "$OUTPUT_PATH"
}

# Main assembly function that orchestrates all assembly operations
assemble_final_image() {
  print_info "Assembling the final disk image..."
  print_debug "Output path: $OUTPUT_PATH"
  
  # Calculate required image size
  local total_size_mb
  total_size_mb=$(calculate_image_size)
  
  # Create and partition disk image
  create_disk_image "$total_size_mb"
  partition_disk_image
  
  # Setup loop device and format partitions
  setup_image_loop_device
  format_partitions
  
  # Copy bootloader and rootfs
  copy_bootloader
  copy_rootfs
  
  # Create systemd init symlink
  create_systemd_symlink
  
  # Inject harvested components
  inject_kernel_modules
  inject_firmware
  inject_modprobe_configs
  
  # Create traditional symlinks and reset machine-id
  create_traditional_symlinks
  reset_machine_id
  
  # Fix ownership of output file
  fix_output_ownership
  
  print_info "All done! Your shimboot NixOS image is ready at: $OUTPUT_PATH"
  print_debug "Final image size: $(ls -lh "$OUTPUT_PATH")"
  
  if [ "$USE_RECOVERY" = true ]; then
    print_info "✓ Built with recovery image drivers - should have better hardware support"
  else
    print_info "⚠ Built without recovery image - consider adding ./data/recovery.bin for better compatibility"
  fi
}