# Old Build-Final-Image Process Explained

## Overview

This document provides a comprehensive explanation of the old `build-final-image` process used in the nixos-shimboot project. This process was designed to create a bootable NixOS image that could run on ChromeOS hardware by combining components from both systems.

## Introduction

The `build-final-image` script was a complex shell script that performed the intricate task of creating a hybrid NixOS/ChromeOS image. It extracted components from ChromeOS images, combined them with a NixOS system, and assembled everything into a single bootable disk image that maintained ChromeOS's partition layout while running NixOS as the main operating system.

The process was divided into four main phases:

1. **Initialization and Prerequisites**: Setting up the environment and checking requirements
2. **Harvesting Components**: Extracting kernel, initramfs, modules, and firmware from ChromeOS images
3. **NixOS Image Creation**: Generating a base NixOS system using `nixos-generate`
4. **Image Assembly**: Combining all components into the final bootable image

This document explains each phase in detail, providing insights into the technical challenges and solutions implemented in the old build process.

## Phase 1: Initialization and Prerequisites

### Purpose

The first phase focused on setting up the build environment, checking for required tools and files, and establishing the configuration for the build process.

### Key Activities

1. **Environment Setup**:
   - Created temporary directories for build artifacts
   - Established logging and error handling mechanisms
   - Set up cleanup hooks to ensure proper resource cleanup

2. **Prerequisite Checking**:
   - Verified the availability of required tools (nix, cgpt, binwalk, etc.)
   - Checked for the existence of required files (shim.bin, bootloader directory)
   - Confirmed sudo access for operations requiring root privileges

3. **Configuration Loading**:
   - Loaded configuration from environment variables and config files
   - Processed command-line arguments
   - Set up WiFi credentials if provided

### Technical Details

The script used a modular approach with library files for different functionalities:

- `common.sh`: Common utilities and helper functions
- `prerequisites.sh`: Functions for checking system requirements
- `config.sh`: Configuration management functions
- `cleanup.sh`: Resource cleanup functions

This modular design made the code more maintainable and allowed for reuse of functionality across different parts of the script.

### Challenges and Solutions

**Challenge**: Ensuring all required tools were available and properly configured.

**Solution**: The script implemented comprehensive checking with clear error messages:

```bash
check_prerequisites() {
    # Check for required tools
    for tool in nix cgpt binwalk nixos-generate jq hexdump strings fdisk tar gunzip git; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_error "Required tool '$tool' not found in PATH"
            exit 1
        fi
    done
    
    # Check for required files
    if [ ! -f "$SHIM_FILE" ]; then
        print_error "Shim file not found: $SHIM_FILE"
        exit 1
    fi
}
```

## Phase 2: Harvesting Components

### Purpose

The second phase extracted critical components from ChromeOS images that would be needed for hardware compatibility in the final NixOS image.

### Key Activities

1. **Kernel Extraction**:
   - Located and extracted the kernel partition from the ChromeOS shim image
   - Used `cgpt` to identify partition boundaries
   - Used `dd` to extract the raw kernel data

2. **Initramfs Extraction**:
   - Decompressed the kernel to access the initramfs
   - Used `binwalk` to identify compression layers
   - Extracted and decompressed the initramfs cpio archive

3. **Component Harvesting**:
   - Mounted ChromeOS rootfs partitions
   - Copied kernel modules and firmware
   - Extracted modprobe configurations

4. **Initramfs Patching**:
   - Modified the initramfs to include shimboot bootloader
   - Added hooks for custom initialization
   - Repackaged the initramfs

### Technical Details

The kernel extraction process was particularly complex due to ChromeOS's multi-layer compression scheme:

```bash
# Extract kernel partition
kernel_start=$(cgpt show -i 2 -b "$SHIM_FILE")
kernel_size=$(cgpt show -i 2 -s "$SHIM_FILE")
dd if="$SHIM_FILE" of="$KERNEL_FILE" bs=512 skip="$kernel_start" count="$kernel_size"

# Extract initramfs from kernel
gzip_offset=$(binwalk -y gzip "$KERNEL_FILE" | grep "gzip compressed data" | head -n 1 | awk '{print $1}')
dd if="$KERNEL_FILE" bs=1 skip="$gzip_offset" | gunzip > "$DECOMPRESSED_KERNEL"

xz_offset=$(binwalk -y xz "$DECOMPRESSED_KERNEL" | grep "XZ compressed data" | head -n 1 | awk '{print $1}')
dd if="$DECOMPRESSED_KERNEL" bs=1 skip="$xz_offset" | xz -d | cpio -id
```

### Challenges and Solutions

**Challenge**: Extracting the initramfs from the ChromeOS kernel required handling multiple compression layers.

**Solution**: The script used a two-stage extraction process with `binwalk` to identify compression boundaries:

1. First, it identified and extracted the gzip-compressed kernel
2. Then, it identified and extracted the XZ-compressed initramfs from within the kernel

**Challenge**: Ensuring hardware compatibility by extracting the correct drivers and firmware.

**Solution**: The script harvested components from both the shim and recovery images:

```bash
# Mount shim and extract modules
mount "$SHIM_LOOP"p3 "$SHIM_MOUNT"
cp -r "$SHIM_MOUNT/lib/modules/$KERNEL_VERSION" "$TMP_DIR/kernel_modules"

# Mount recovery and extract additional firmware
if [ -f "$RECOVERY_FILE" ]; then
    mount "$RECOVERY_LOOP"p3 "$RECOVERY_MOUNT"
    cp -r "$RECOVERY_MOUNT/lib/firmware"/* "$TMP_DIR/firmware/"
fi
```

## Phase 3: NixOS Image Creation

### Purpose

The third phase generated a base NixOS system using the `nixos-generate` command, which would later be combined with the ChromeOS components.

### Key Activities

1. **NixOS Configuration**:
   - Used a custom `configuration.nix` file to define the NixOS system
   - Included patched systemd for ChromeOS compatibility
   - Configured system packages and services

2. **Image Generation**:
   - Executed `nixos-generate` to create a raw disk image
   - Extracted the image path from the command output
   - Verified the image was created successfully

3. **Image Preparation**:
   - Mounted the NixOS image for later access
   - Analyzed the image structure and size
   - Prepared for integration with ChromeOS components

### Technical Details

The NixOS image generation was the most time-consuming part of the process:

```bash
print_info "Building NixOS raw disk image..."
print_info "  This may take 10-30 minutes on first run as it downloads and builds all packages..."
print_info "  Building with verbose output to show progress..."

print_debug "Running: nixos-generate -f raw -c ./configuration.nix --system x86_64-linux --show-trace"

# Generate the image
nixos-generate -f raw -c ./configuration.nix --system x86_64-linux --show-trace

# Extract the image path
NIXOS_IMAGE_PATH=$(nixos-generate -f raw -c ./configuration.nix --system x86_64-linux --show-trace | grep -o "/nix/store/[^[:space:]]*-nixos-disk-image/nixos.img")

if [ -z "$NIXOS_IMAGE_PATH" ]; then
    print_error "Failed to extract NixOS image path from nixos-generate output"
    exit 1
fi
```

### Challenges and Solutions

**Challenge**: The `nixos-generate` command was time-consuming and resource-intensive.

**Solution**: The script provided clear progress feedback and warnings about the expected duration:

```bash
print_info "  This may take 10-30 minutes on first run as it downloads and builds all packages..."
print_info "  Building with verbose output to show progress..."
```

**Challenge**: Ensuring the NixOS system was compatible with ChromeOS hardware.

**Solution**: The configuration included a patched systemd package with ChromeOS-specific modifications:

```nix
# In configuration.nix
systemd = pkgs.systemd.overrideAttrs (oldAttrs: {
  patches = [ ./systemd-mount-nofollow.patch ];
});
```

## Phase 4: Image Assembly

### Purpose

The fourth and final phase combined all the components into a single bootable image with the correct partition layout for ChromeOS hardware.

### Key Activities

1. **Image Creation**:
   - Created a new disk image with the appropriate size
   - Partitioned the image according to ChromeOS layout
   - Formatted each partition with the correct filesystem

2. **Component Integration**:
   - Copied the NixOS rootfs to the main partition
   - Installed the patched initramfs to the bootloader partition
   - Injected ChromeOS drivers and firmware into the NixOS system

3. **System Configuration**:
   - Created the systemd init symlink
   - Reset the machine ID for first-boot generation
   - Fixed ownership and permissions

### Technical Details

The partition layout was critical for ChromeOS compatibility:

```bash
# Create GPT partition table
parted -s "$OUTPUT_PATH" mklabel gpt

# Create partitions
# 1. STATE partition (1MB)
parted -s "$OUTPUT_PATH" mkpart primary linux-swap 2048s 4095s
parted -s "$OUTPUT_PATH" name 1 "STATE"

# 2. KERN-A partition (32MB)
parted -s "$OUTPUT_PATH" mkpart primary 4096s 69631s
parted -s "$OUTPUT_PATH" name 2 "KERN-A"
parted -s "$OUTPUT_PATH" set 2 boot on

# 3. ROOT-A partition (32MB)
parted -s "$OUTPUT_PATH" mkpart primary 69632s 135167s
parted -s "$OUTPUT_PATH" name 3 "ROOT-A"

# 4. Rootfs partition (remaining space)
parted -s "$OUTPUT_PATH" mkpart primary ext4 135168s "${rootfs_end_sector}s"
parted -s "$OUTPUT_PATH" name 4 "ROOTFS"
```

### Challenges and Solutions

**Challenge**: Calculating the correct partition sizes to accommodate all components.

**Solution**: The script calculated sizes based on the actual space used by the NixOS system plus a buffer:

```bash
# Calculate required sizes
nixos_used_space=$(df -m "$NIXOS_SOURCE_MOUNT" | awk 'NR==2 {print $3}')
final_rootfs_size=$((nixos_used_space + 2871))  # Add buffer
bootloader_size=32  # 32MB for bootloader partition
total_size=$((final_rootfs_size + bootloader_size + 1))  # +1MB for state
```

**Challenge**: Ensuring the system would boot correctly on ChromeOS hardware.

**Solution**: The script carefully integrated ChromeOS components with the NixOS system:

```bash
# Inject ChromeOS components
cp -r "$TMP_DIR/kernel_modules" "$ROOTFS_MOUNT/lib/"
cp -r "$TMP_DIR/firmware" "$ROOTFS_MOUNT/lib/firmware/"
cp -r "$TMP_DIR/modprobe.d"/* "$ROOTFS_MOUNT/etc/modprobe.d/"

# Create systemd init symlink
systemd_binary=$(find "$ROOTFS_MOUNT/nix/store" -name "systemd" -type f -executable | head -n 1)
systemd_binary_path="${systemd_binary#$ROOTFS_MOUNT}"
ln -s "$systemd_binary_path" "$ROOTFS_MOUNT/init"
```

## Key Technical Insights

### ChromeOS and NixOS Integration

The build process demonstrated several key insights about integrating ChromeOS and NixOS:

1. **Partition Layout**: ChromeOS requires a specific GPT partition layout with STATE, KERN-A, ROOT-A, and ROOTFS partitions.

2. **Boot Process**: The boot process involves the ChromeOS bootloader loading the kernel and initramfs from the KERN-A and ROOT-A partitions.

3. **Hardware Compatibility**: ChromeOS devices require specific kernel modules and firmware that aren't typically included in NixOS.

4. **System Requirements**: NixOS needs specific patches (like the systemd mount_nofollow patch) to work correctly on ChromeOS hardware.

### Build Process Optimization

The build process included several optimizations:

1. **Caching**: The Nix store provided automatic caching of packages, speeding up subsequent builds.

2. **Parallel Processing**: Multiple operations could run in parallel where possible.

3. **Resource Management**: The script carefully managed temporary resources and cleaned up after itself.

4. **Error Recovery**: The script included error handling and recovery mechanisms for common failure points.

## Limitations and Challenges

### Technical Limitations

1. **ChromeOS Model Specificity**: The build process was tailored to specific ChromeOS models and might not work on others.

2. **Kernel Version Dependency**: The process depended on specific kernel versions and might break with ChromeOS updates.

3. **NixOS Configuration Complexity**: The NixOS configuration required careful tuning to work with ChromeOS hardware.

### Process Challenges

1. **Build Time**: The process was time-consuming, especially on first runs.

2. **Resource Requirements**: The process required significant disk space, memory, and CPU resources.

3. **Error Handling**: While comprehensive, the error handling couldn't account for all possible failure scenarios.

## Evolution Opportunities

Based on the analysis of the old build process, several evolution opportunities were identified:

1. **Modularization**: Breaking the script into smaller, more focused modules for better maintainability.

2. **Configuration Management**: Externalizing configuration options to make the script more flexible.

3. **Error Recovery**: Implementing more robust error recovery mechanisms.

4. **Documentation**: Improving inline documentation and comments for better understanding.

5. **Testing**: Adding automated testing for different scenarios and ChromeOS models.

## Conclusion

The old `build-final-image` process was a sophisticated solution for creating a NixOS image that could run on ChromeOS hardware. It demonstrated advanced techniques for:

1. Extracting and modifying components from existing systems
2. Integrating components from multiple sources
3. Handling complex technical challenges with creative solutions
4. Managing system resources and cleanup

While the process had its challenges and limitations, it represented a significant technical achievement in enabling NixOS to run on ChromeOS hardware. The detailed documentation provided in this archive serves as a valuable resource for understanding the complexities of systems integration and the technical decisions made in the original implementation.

The lessons learned from this process are invaluable for future development of similar systems integration projects, and the techniques demonstrated here could be applied to other scenarios where different operating systems need to be combined or adapted for specific hardware platforms.