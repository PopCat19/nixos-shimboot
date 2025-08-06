#!/usr/bin/env bash

# --- Driver and Kernel Harvesting Functions ---

# Mount and harvest kernel modules from shim
harvest_shim_modules() {
  print_info "Mounting original ChromeOS rootfs to harvest modules..."
  
  SHIM_LOOP=$(create_loop_device "$SHIM_FILE")
  print_debug "Assigned shim loop device: $SHIM_LOOP"
  
  # The ChromeOS rootfs is usually partition 3 (ROOT-A)
  local shim_rootfs_part="${SHIM_LOOP}p3"
  if [ ! -b "$shim_rootfs_part" ]; then
    print_error "Could not find shim rootfs partition at $shim_rootfs_part"
    exit 1
  fi
  
  SHIM_ROOTFS_MOUNT=$(create_temp_dir "shim_rootfs_mount")
  print_debug "Mounting shim rootfs partition: $shim_rootfs_part -> $SHIM_ROOTFS_MOUNT"
  sudo mount -o ro "$shim_rootfs_part" "$SHIM_ROOTFS_MOUNT"
  
  # Find the kernel module directory dynamically
  local kmod_dir_name
  kmod_dir_name=$(sudo ls "$SHIM_ROOTFS_MOUNT/lib/modules/" | head -n 1)
  local kmod_src_path="$SHIM_ROOTFS_MOUNT/lib/modules/$kmod_dir_name"
  KMOD_DEST_PATH="$TMP_DIR/kernel_modules"
  
  print_debug "Looking for modules in $kmod_src_path"
  if [ -d "$kmod_src_path" ]; then
    print_info "Found modules for kernel $kmod_dir_name, copying..."
    # Copy the entire modules directory structure like original
    sudo cp -ar "$SHIM_ROOTFS_MOUNT/lib/modules" "$KMOD_DEST_PATH"
    print_debug "Shim modules harvested successfully to $KMOD_DEST_PATH"
  else
    print_error "Could not find kernel module directory in shim rootfs!"
    sudo ls -la "$SHIM_ROOTFS_MOUNT/lib/modules/"
    exit 1
  fi
  
  # Harvest firmware from shim
  print_info "Harvesting firmware from shim..."
  FIRMWARE_DEST_PATH="$TMP_DIR/firmware"
  mkdir -p "$FIRMWARE_DEST_PATH"
  if [ -d "$SHIM_ROOTFS_MOUNT/lib/firmware" ]; then
    sudo cp -ar "$SHIM_ROOTFS_MOUNT/lib/firmware"/* "$FIRMWARE_DEST_PATH/" 2>/dev/null || true
    print_debug "Shim firmware copied to $FIRMWARE_DEST_PATH"
  fi
  
  unmount_if_mounted "$SHIM_ROOTFS_MOUNT"
  remove_temp_dir "$SHIM_ROOTFS_MOUNT"
  detach_loop_device "$SHIM_LOOP"
  SHIM_LOOP=""
}

# Mount and harvest additional drivers from recovery image
harvest_recovery_drivers() {
  if [ "$USE_RECOVERY" != true ]; then
    print_debug "Skipping recovery image harvest - no recovery file available"
    return
  fi
  
  print_info "Mounting recovery image to harvest additional drivers..."
  RECOVERY_LOOP=$(create_loop_device "$RECOVERY_FILE")
  print_debug "Assigned recovery loop device: $RECOVERY_LOOP"
  
  # Recovery rootfs is usually partition 3 (ROOT-A)
  local recovery_rootfs_part="${RECOVERY_LOOP}p3"
  if [ ! -b "$recovery_rootfs_part" ]; then
    print_error "Could not find recovery rootfs partition at $recovery_rootfs_part"
    exit 1
  fi
  
  RECOVERY_ROOTFS_MOUNT=$(create_temp_dir "recovery_rootfs_mount")
  print_debug "Mounting recovery rootfs partition: $recovery_rootfs_part -> $RECOVERY_ROOTFS_MOUNT"
  sudo mount -o ro "$recovery_rootfs_part" "$RECOVERY_ROOTFS_MOUNT"
  
  # Harvest additional firmware from recovery
  print_info "Harvesting additional firmware from recovery image..."
  if [ -d "$RECOVERY_ROOTFS_MOUNT/lib/firmware" ]; then
    sudo cp -ar "$RECOVERY_ROOTFS_MOUNT/lib/firmware"/* "$FIRMWARE_DEST_PATH/" 2>/dev/null || true
    print_debug "Recovery firmware merged into $FIRMWARE_DEST_PATH"
  fi
  
  # Harvest modprobe configurations
  print_info "Harvesting modprobe configurations from recovery..."
  MODPROBE_DEST_PATH="$TMP_DIR/modprobe.d"
  mkdir -p "$MODPROBE_DEST_PATH"
  
  if [ -d "$RECOVERY_ROOTFS_MOUNT/lib/modprobe.d" ]; then
    sudo cp -ar "$RECOVERY_ROOTFS_MOUNT/lib/modprobe.d"/* "$MODPROBE_DEST_PATH/" 2>/dev/null || true
    print_debug "Recovery lib modprobe.d copied"
  fi
  
  if [ -d "$RECOVERY_ROOTFS_MOUNT/etc/modprobe.d" ]; then
    sudo cp -ar "$RECOVERY_ROOTFS_MOUNT/etc/modprobe.d"/* "$MODPROBE_DEST_PATH/" 2>/dev/null || true
    print_debug "Recovery etc modprobe.d copied"
  fi
  
  unmount_if_mounted "$RECOVERY_ROOTFS_MOUNT"
  remove_temp_dir "$RECOVERY_ROOTFS_MOUNT"
  detach_loop_device "$RECOVERY_LOOP"
  RECOVERY_LOOP=""
}

# Extract kernel partition (KERN-A)
extract_kernel_partition() {
  print_info "Extracting kernel partition (KERN-A)..."
  print_debug "Running: sudo cgpt show -i 2 \"$SHIM_FILE\""
  
  local cgpt_output
  cgpt_output=$(sudo cgpt show -i 2 "$SHIM_FILE")
  print_debug "cgpt output:"
  print_debug "$cgpt_output"
  
  local part_start part_size
  read -r part_start part_size _ < <(
    echo "$cgpt_output" | awk '$4 == "Label:" && $5 == "\"KERN-A\""'
  )
  print_debug "Partition start: $part_start, size: $part_size"
  
  print_debug "Extracting kernel with dd..."
  sudo dd if="$SHIM_FILE" of="$KERNEL_FILE" bs=512 skip="$part_start" count="$part_size" status=progress
  
  print_debug "Fixing ownership of $KERNEL_FILE..."
  sudo chown "$(id -u):$(id -g)" "$KERNEL_FILE"
}

# Extract initramfs from kernel
extract_initramfs() {
  print_info "Extracting initramfs from kernel..."
  print_debug "Stage 1: Finding gzip offset..."
  
  local tmp_log_1
  tmp_log_1=$(mktemp)
  binwalk -y gzip -l "$tmp_log_1" "$KERNEL_FILE"
  
  local offset
  offset=$(grep '"offset"' "$tmp_log_1" | awk -F': ' '{print $2}' | sed 's/,//')
  rm "$tmp_log_1"
  print_debug "Gzip offset: $offset"
  
  print_debug "Stage 1: Decompressing kernel..."
  dd if="$KERNEL_FILE" bs=1 skip="$offset" | zcat >"$TMP_DIR/decompressed_kernel.bin" || true
  
  print_debug "Stage 2: Finding XZ offset..."
  local tmp_log_2
  tmp_log_2=$(mktemp)
  binwalk -l "$tmp_log_2" "$TMP_DIR/decompressed_kernel.bin"
  
  local xz_offset
  xz_offset=$(cat "$tmp_log_2" | jq '.[0].Analysis.file_map[] | select(.description | contains("XZ compressed data")) | .offset')
  rm "$tmp_log_2"
  print_debug "XZ offset: $xz_offset"
  
  mkdir -p "$TMP_DIR/initramfs_extracted"
  print_debug "Stage 2: Extracting XZ cpio archive..."
  dd if="$TMP_DIR/decompressed_kernel.bin" bs=1 skip="$xz_offset" | xz -d | cpio -id -D "$TMP_DIR/initramfs_extracted" || true
  print_debug "Initramfs extraction complete."
}

# Patch initramfs with shimboot bootloader
patch_initramfs() {
  print_info "Patching initramfs with shimboot bootloader..."
  local original_init="$TMP_DIR/initramfs_extracted/init"
  print_debug "Original init script: $original_init"
  print_debug "Copying bootloader from: $BOOTLOADER_DIR"
  cp -rT "$BOOTLOADER_DIR" "$TMP_DIR/initramfs_extracted/"
  print_debug "Adding exec hook to init script..."
  echo 'exec /bin/bootstrap.sh' >>"$original_init"
  print_debug "Making bootloader scripts executable..."
  find "$TMP_DIR/initramfs_extracted/bin" -type f -exec chmod +x {} \;
  print_debug "Initramfs patching complete"
}

# Main harvesting function that orchestrates all harvesting operations
harvest_all() {
  print_info "Harvesting kernel, initramfs, and modules from shim..."
  
  # Create temporary directory
  TMP_DIR=$(create_temp_dir)
  print_info "Working directory: $TMP_DIR"
  print_debug "Temp directory permissions: $(ls -ld "$TMP_DIR")"
  
  # Harvest kernel modules from shim
  harvest_shim_modules
  
  # Harvest additional drivers from recovery image
  harvest_recovery_drivers
  
  # Extract kernel partition
  extract_kernel_partition
  
  # Extract initramfs
  extract_initramfs
  
  # Patch initramfs
  patch_initramfs
}