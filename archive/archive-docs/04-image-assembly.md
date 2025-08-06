# Phase 4: Image Assembly

## Overview

The fourth and final phase of the old build process involved assembling the final shimboot image by combining the NixOS rootfs with the harvested ChromeOS components. This phase was where all the previous work came together to create a bootable NixOS image that could run on ChromeOS hardware.

## Mounting NixOS Image

### Loop Device Creation

The process began by mounting the NixOS image to access its contents:

```bash
print_info "Mounting source NixOS image to extract rootfs..."
print_debug "NixOS image path: $nixos_image_path"

NIXOS_LOOP=$(create_loop_device "$nixos_image_path")
print_debug "Assigned NixOS source loop device: $NIXOS_LOOP"

# Mount the NixOS partition (typically partition 1)
local nixos_part="${NIXOS_LOOP}p1"
if [ ! -b "$nixos_part" ]; then
    print_error "Could not find NixOS partition at $nixos_part"
    exit 1
fi

NIXOS_SOURCE_MOUNT=$(create_temp_dir "nixos_source_mount")
print_debug "Mounting NixOS source partition: $nixos_part -> $NIXOS_SOURCE_MOUNT"
sudo mount "$nixos_part" "$NIXOS_SOURCE_MOUNT"
```

**Technical Details**:
- A loop device was created to access the NixOS image as a block device
- The NixOS image typically used partition 1 for the root filesystem
- The partition was mounted to a temporary directory for file operations

## Final Image Creation

### Size Estimation

The script calculated the required size for the final image:

```bash
print_info "Assembling the final disk image..."
print_debug "Output path: $OUTPUT_PATH"

# Estimate required rootfs size from source NixOS image
local nixos_used_space
nixos_used_space=$(df -m "$NIXOS_SOURCE_MOUNT" | awk 'NR==2 {print $3}')
print_debug "NixOS used space: ${nixos_used_space}MB"

# Calculate final partition sizes with some buffer
local final_rootfs_size=$((nixos_used_space + 2871))  # Add buffer for ChromeOS components
local bootloader_size=32  # 32MB for bootloader partition
local total_size=$((final_rootfs_size + bootloader_size + 1))  # +1MB for state partition

print_debug "Final rootfs partition size: ${final_rootfs_size}MB"
print_debug "Bootloader partition size: ${bootloader_size}MB"
print_debug "Total image size: ${total_size}MB"
```

**Key Calculations**:
- The script used `df` to measure the actual space used by the NixOS rootfs
- A buffer of approximately 2.8GB was added to accommodate ChromeOS components
- The bootloader partition was fixed at 32MB
- An additional 1MB was allocated for the state partition

### Image Creation

The script created the final disk image using `dd`:

```bash
print_info "Creating ${total_size}MB disk image"
print_debug "Creating disk image with dd: bs=1M count=${total_size}"

# Create the disk image file
dd if=/dev/zero of="$OUTPUT_PATH" bs=1M count="${total_size}" status=progress
```

**Technical Details**:
- `dd` was used to create a sparse file filled with zeros
- The block size was set to 1MB for efficiency
- The `status=progress` option provided progress updates during the creation

## Partitioning the Image

### GPT Partition Table

The script partitioned the image using a GPT partition table:

```bash
print_info "Partitioning disk image"

# Create the GPT partition table
sudo parted -s "$OUTPUT_PATH" mklabel gpt

# Create partitions
# 1. STATE partition (1MB)
sudo parted -s "$OUTPUT_PATH" mkpart primary linux-swap 2048s 4095s
sudo parted -s "$OUTPUT_PATH" name 1 "STATE"

# 2. KERN-A partition (32MB)
sudo parted -s "$OUTPUT_PATH" mkpart primary 4096s 69631s
sudo parted -s "$OUTPUT_PATH" name 2 "KERN-A"
sudo parted -s "$OUTPUT_PATH" set 2 boot on

# 3. ROOT-A partition (32MB)
sudo parted -s "$OUTPUT_PATH" mkpart primary 69632s 135167s
sudo parted -s "$OUTPUT_PATH" name 3 "ROOT-A"

# 4. Rootfs partition (remaining space)
local rootfs_start_sector=135168
local rootfs_end_sector=$((total_size * 2048 - 1))
sudo parted -s "$OUTPUT_PATH" mkpart primary ext4 "${rootfs_start_sector}s" "${rootfs_end_sector}s"
sudo parted -s "$OUTPUT_PATH" name 4 "ROOTFS"

# Verify the partition table
print_debug "Verifying partition table:"
sudo fdisk -l "$OUTPUT_PATH"
```

**Partition Layout**:
1. **STATE**: 1MB partition for system state (sectors 2048-4095)
2. **KERN-A**: 32MB partition for the kernel (sectors 4096-69631)
   - Marked as bootable
3. **ROOT-A**: 32MB partition for the ChromeOS rootfs (sectors 69632-135167)
4. **ROOTFS**: Remaining space for the NixOS rootfs

**Key Notes**:
- The partition layout matched ChromeOS's standard GPT scheme
- Sector calculations were based on 512-byte sectors
- The KERN-A partition was marked as bootable

### Loop Device Setup

The script created a loop device for the final image:

```bash
print_info "Creating loop device for final image"
IMAGE_LOOP=$(create_loop_device "$OUTPUT_PATH")
print_debug "Assigned final image loop device: $IMAGE_LOOP"
```

## Formatting Partitions

### Filesystem Creation

Each partition was formatted with the appropriate filesystem:

```bash
print_info "Formatting partitions"

# Format STATE partition (no filesystem needed, just initialize)
sudo mkfs.vfat -F 32 -n "STATE" "${IMAGE_LOOP}p1" 2>/dev/null || true

# Format KERN-A partition (no filesystem, will be written raw)
# Just ensure it's cleared
sudo dd if=/dev/zero of="${IMAGE_LOOP}p2" bs=1M count=32 status=none

# Format ROOT-A partition with ext2
sudo mkfs.ext2 -L "ROOT-A" "${IMAGE_LOOP}p3" <<EOF
y
EOF

# Format ROOTFS partition with ext4
sudo mkfs.ext4 -L "ROOTFS" "${IMAGE_LOOP}p4" <<EOF
y
EOF
```

**Technical Details**:
- **STATE**: Formatted as FAT32 for compatibility with ChromeOS
- **KERN-A**: Cleared with zeros but not formatted (kernel is written raw)
- **ROOT-A**: Formatted as ext2 for the ChromeOS rootfs
- **ROOTFS**: Formatted as ext4 for the NixOS rootfs

## Copying Components

### Bootloader Installation

The script copied the bootloader to the ROOT-A partition:

```bash
print_info "Copying bootloader..."

# Mount the ROOT-A partition
BOOTLOADER_MOUNT=$(create_temp_dir "shim_bootloader")
sudo mount "${IMAGE_LOOP}p3" "$BOOTLOADER_MOUNT"

# Copy the patched initramfs to the bootloader partition
if [ -d "$TMP_DIR/initramfs_extracted" ]; then
    sudo cp -r "$TMP_DIR/initramfs_extracted/"* "$BOOTLOADER_MOUNT/"
    print_debug "Copied initramfs to bootloader partition"
else
    print_warning "No initramfs_extracted directory found"
fi

# Unmount the bootloader partition
unmount_if_mounted "$BOOTLOADER_MOUNT"
remove_temp_dir "$BOOTLOADER_MOUNT"
```

**Key Notes**:
- The bootloader was installed in the ROOT-A partition
- The patched initramfs from the harvesting phase was copied
- If no initramfs was found, a warning was issued but the process continued

### NixOS Rootfs Copy

The script copied the NixOS rootfs to the ROOTFS partition:

```bash
print_info "Copying NixOS rootfs... (this may take a while)"
print_debug "Copying rootfs from source image to partition..."

# Mount the ROOTFS partition
ROOTFS_MOUNT=$(create_temp_dir "new_rootfs")
sudo mount "${IMAGE_LOOP}p4" "$ROOTFS_MOUNT"

# Copy the entire NixOS rootfs
sudo cp -a "$NIXOS_SOURCE_MOUNT/"* "$ROOTFS_MOUNT/"
print_debug "Rootfs copy complete"
```

**Technical Details**:
- The NixOS rootfs was copied using `cp -a` to preserve all attributes
- This was typically the most time-consuming part of the build process
- The entire NixOS system, including packages and configurations, was copied

## System Configuration

### Systemd Symlink

The script created a symlink for the systemd init:

```bash
print_info "Creating systemd init symlink..."

# Find the systemd binary
local systemd_binary=""
if [ -n "$SYSTEMD_BINARY_PATH" ] && [ -e "$ROOTFS_MOUNT$SYSTEMD_BINARY_PATH" ]; then
    systemd_binary="$SYSTEMD_BINARY_PATH"
    print_debug "Using manually specified systemd binary path: $systemd_binary"
else
    # Search for systemd in the Nix store
    systemd_binary=$(find "$ROOTFS_MOUNT/nix/store" -name "systemd" -type f -executable 2>/dev/null | head -n 1)
    if [ -z "$systemd_binary" ]; then
        print_error "No systemd binary found in the Nix store!"
        exit 1
    fi
    print_debug "Found systemd binary at: $systemd_binary"
fi

# Create the symlink
systemd_binary_path="${systemd_binary#$ROOTFS_MOUNT}"
ln -s "$systemd_binary_path" "$ROOTFS_MOUNT/init"
print_debug "Created symlink /init -> $systemd_binary_path"
```

**Key Notes**:
- The script looked for a systemd binary in the Nix store
- It could use a manually specified path or search for one
- A symlink from `/init` to the systemd binary was created for boot

### Component Injection

The script injected the harvested components into the new rootfs:

```bash
# Inject kernel modules
if [ -d "$TMP_DIR/kernel_modules" ]; then
    print_info "Injecting harvested kernel modules into new rootfs..."
    sudo cp -r "$TMP_DIR/kernel_modules" "$ROOTFS_MOUNT/lib/"
    print_debug "Modules copied to $ROOTFS_MOUNT/lib/modules/"
    
    # Decompress kernel modules if needed
    find "$ROOTFS_MOUNT/lib/modules" -name "*.ko.xz" -exec xz -d {} \;
    find "$ROOTFS_MOUNT/lib/modules" -name "*.ko.gz" -exec gunzip {} \;
else
    print_warning "Harvested kernel modules not found in temp directory. Skipping."
fi

# Inject firmware
if [ -d "$TMP_DIR/firmware" ]; then
    print_info "Injecting harvested firmware into new rootfs..."
    sudo cp -r "$TMP_DIR/firmware"/* "$ROOTFS_MOUNT/lib/firmware/" 2>/dev/null || true
    print_debug "Firmware copied to $ROOTFS_MOUNT/lib/firmware/"
else
    print_warning "Harvested firmware not found in temp directory. Skipping."
fi

# Inject modprobe configurations
if [ -d "$TMP_DIR/modprobe.d" ]; then
    print_info "Injecting modprobe configurations into new rootfs..."
    sudo cp -r "$TMP_DIR/modprobe.d"/* "$ROOTFS_MOUNT/etc/modprobe.d/" 2>/dev/null || true
    print_debug "Modprobe configurations copied"
fi
```

**Technical Details**:
- **Kernel Modules**: Copied to `/lib/modules/` and decompressed if needed
- **Firmware**: Copied to `/lib/firmware/` for hardware support
- **Modprobe Configurations**: Copied to `/etc/modprobe.d/` for module loading

### Machine ID Reset

The script reset the machine ID for the golden image:

```bash
print_info "Resetting machine-id for golden image..."

# Remove existing machine-id if present
if [ -f "$ROOTFS_MOUNT/etc/machine-id" ]; then
    sudo rm "$ROOTFS_MOUNT/etc/machine-id"
fi

# Create an empty machine-id file for first-boot generation
sudo touch "$ROOTFS_MOUNT/etc/machine-id"
print_debug "Ensured /etc/machine-id is ready for first-boot generation."
```

**Key Notes**:
- The machine ID was reset to ensure each installation gets a unique ID
- An empty file was created, which systemd will populate on first boot

## Finalization

### Ownership and Permissions

The script fixed the ownership of the output file:

```bash
print_debug "Fixing ownership of output file..."
sudo chown "$(id -u):$(id -g)" "$OUTPUT_PATH"
```

### Cleanup

The script cleaned up temporary resources:

```bash
# Unmount filesystems
unmount_if_mounted "$ROOTFS_MOUNT"
unmount_if_mounted "$NIXOS_SOURCE_MOUNT"

# Detach loop devices
detach_loop_device "$IMAGE_LOOP"
detach_loop_device "$NIXOS_LOOP"

# Remove temporary directories
remove_temp_dir "$TMP_DIR"
```

## Completion

The script reported successful completion:

```bash
print_info "All done! Your shimboot NixOS image is ready at: $OUTPUT_PATH"
print_debug "Final image size: $(ls -lh "$OUTPUT_PATH")"

if [ "$USE_RECOVERY" = true ]; then
    print_info "✓ Built with recovery image drivers - should have better hardware support"
else
    print_warning "⚠ Built without recovery image - consider adding ./data/recovery.bin for better compatibility"
fi
```

## Critical Considerations

1. **Partition Layout**: The GPT partition table must exactly match ChromeOS's expectations for the device to boot properly.

2. **Component Integration**: The successful integration of ChromeOS components (kernel modules, firmware) was critical for hardware compatibility.

3. **Systemd Dependency**: The boot process relied on systemd, and the correct version and patching were essential.

4. **Space Management**: The size calculations needed to be accurate to ensure all components fit without wasting space.

5. **Filesystem Compatibility**: The choice of filesystems (ext2 for ROOT-A, ext4 for ROOTFS) was important for both ChromeOS compatibility and NixOS functionality.

6. **Error Handling**: The process included error handling at each step, but some failures (like missing initramfs) were treated as warnings rather than fatal errors.

7. **Performance**: The rootfs copy operation was time-consuming and required significant disk I/O.

8. **Cleanup**: Proper cleanup of temporary resources was essential to avoid leaving the system in an inconsistent state.

This phase was where all the previous work came together, creating a bootable NixOS image that could run on ChromeOS hardware by combining the NixOS system with ChromeOS drivers and firmware.