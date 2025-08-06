# Phase 2: Harvesting Components

## Overview

The second phase of the old build process involved extracting critical components from the ChromeOS shim image and optionally from a recovery image. This phase was technically complex as it required deep manipulation of binary firmware images to extract kernel modules, firmware, and the initramfs.

## Kernel Module Extraction

### Mounting the ChromeOS Shim Image

The process began by mounting the ChromeOS shim image to access its root filesystem:

```bash
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
```

**Key Notes**:
- The ChromeOS shim image used a GPT partition table with multiple partitions
- Partition 3 (ROOT-A) contained the root filesystem with kernel modules
- The image was mounted read-only to prevent accidental modifications
- A loop device was used to access the partition as a block device

### Extracting Kernel Modules

Once mounted, the script extracted the kernel modules:

```bash
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
```

**Technical Details**:
- The kernel version was determined dynamically by examining the `/lib/modules` directory
- The entire modules directory structure was preserved to maintain module dependencies
- Modules were copied with permissions intact using `cp -ar` (archive mode, recursive)

### Extracting Firmware

The script also extracted firmware files:

```bash
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
```

**Key Notes**:
- Firmware files were essential for hardware compatibility (WiFi, Bluetooth, etc.)
- The `2>/dev/null || true` handled permission errors gracefully
- After extraction, the filesystem was unmounted and the loop device detached

## Recovery Image Processing (Optional)

If a recovery image was available, the script would harvest additional drivers from it:

```bash
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
```

### Merging Additional Firmware

The script merged firmware from the recovery image with that from the shim:

```bash
  # Harvest additional firmware from recovery
  print_info "Harvesting additional firmware from recovery image..."
  if [ -d "$RECOVERY_ROOTFS_MOUNT/lib/firmware" ]; then
    sudo cp -ar "$RECOVERY_ROOTFS_MOUNT/lib/firmware"/* "$FIRMWARE_DEST_PATH/" 2>/dev/null || true
    print_debug "Recovery firmware merged into $FIRMWARE_DEST_PATH"
  fi
```

**Key Note**: The recovery image often contained additional or updated firmware not present in the shim image, improving hardware compatibility.

### Extracting Modprobe Configurations

The script also extracted modprobe configurations:

```bash
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
```

**Technical Details**:
- Modprobe configurations controlled how kernel modules were loaded
- Both `/lib/modprobe.d` and `/etc/modprobe.d` directories were examined
- These configurations were essential for proper hardware initialization

## Kernel Partition Extraction

The script extracted the kernel partition (KERN-A) using the ChromeOS GPT utility:

```bash
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
```

**Technical Details**:
- `cgpt` (ChromeOS GPT) was used to query partition information
- Partition 2 was typically the KERN-A partition containing the kernel
- The partition start and size were extracted in 512-byte sectors
- `dd` was used to extract the exact partition content
- File ownership was changed from root to the current user

## Initramfs Extraction

This was the most complex part of the harvesting process, involving multiple stages of decompression:

### Stage 1: Finding Gzip Offset

```bash
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
```

**Technical Details**:
- `binwalk` was used to analyze the kernel binary structure
- The `-y gzip` option limited the search to gzip signatures
- The offset to the gzip-compressed section was extracted from the JSON output

### Stage 2: Decompressing Kernel

```bash
  print_debug "Stage 1: Decompressing kernel..."
  dd if="$KERNEL_FILE" bs=1 skip="$offset" | zcat >"$TMP_DIR/decompressed_kernel.bin" || true
```

**Key Notes**:
- `dd` skipped to the gzip offset and extracted the compressed data
- `zcat` decompressed the gzip stream to reveal the inner kernel structure
- The `|| true` handled decompression errors gracefully

### Stage 3: Finding XZ Offset

```bash
  print_debug "Stage 2: Finding XZ offset..."
  local tmp_log_2
  tmp_log_2=$(mktemp)
  binwalk -l "$tmp_log_2" "$TMP_DIR/decompressed_kernel.bin"
  
  local xz_offset
  xz_offset=$(cat "$tmp_log_2" | jq '.[0].Analysis.file_map[] | select(.description | contains("XZ compressed data")) | .offset')
  rm "$tmp_log_2"
  print_debug "XZ offset: $xz_offset"
```

**Technical Details**:
- The decompressed kernel contained an XZ-compressed initramfs
- `binwalk` analyzed the decompressed kernel to find the XZ signature
- `jq` parsed the JSON output to extract the XZ offset

### Stage 4: Extracting Initramfs

```bash
  mkdir -p "$TMP_DIR/initramfs_extracted"
  print_debug "Stage 2: Extracting XZ cpio archive..."
  dd if="$TMP_DIR/decompressed_kernel.bin" bs=1 skip="$xz_offset" | xz -d | cpio -id -D "$TMP_DIR/initramfs_extracted" || true
  print_debug "Initramfs extraction complete."
}
```

**Technical Details**:
- `dd` skipped to the XZ offset and extracted the compressed data
- `xz -d` decompressed the XZ stream to reveal a cpio archive
- `cpio -id` extracted the cpio archive to a directory
- The `-D` option specified the extraction directory
- The `|| true` handled extraction errors gracefully

## Initramfs Patching

The final step in the harvesting process was patching the initramfs to include the shimboot bootloader:

```bash
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
```

**Technical Details**:
- The entire bootloader directory was copied into the initramfs
- The original init script was modified to execute the bootstrap script
- All bootloader scripts were made executable
- This patching allowed the ChromeOS boot process to chain-load the shimboot bootloader

## Main Harvesting Function

All harvesting operations were orchestrated by a main function:

```bash
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
```

## Critical Considerations

1. **Binary Analysis Complexity**: The initramfs extraction process was particularly complex due to the nested compression (gzip within XZ within the kernel binary).

2. **Tool Dependencies**: The process relied heavily on specific tools (`binwalk`, `cgpt`, `dd`) with particular behaviors. Different versions of these tools could produce different results.

3. **ChromeOS Version Compatibility**: The extraction process assumed specific ChromeOS filesystem structures. Different ChromeOS versions might have different layouts or compression schemes.

4. **Error Handling**: The process used `|| true` in many places to handle errors gracefully, but this could mask actual problems that needed attention.

5. **Temporary Space**: The harvesting process required significant temporary disk space for extracted components.

6. **Kernel Module Dependencies**: The process preserved the entire module directory structure to maintain module dependencies, which was critical for hardware functionality.

7. **Firmware Completeness**: The merging of firmware from both shim and recovery images was essential for comprehensive hardware support.

8. **Initramfs Patching**: The modification of the init script was a critical step that enabled the chain-loading of the shimboot bootloader.

This phase was technically the most challenging part of the build process, requiring deep knowledge of ChromeOS internals, binary file formats, and low-level system utilities.