# Old Build Process Explanation: build-final-image

This document explains how the old method of `build-final-image` worked in the shimboot project. The process was implemented as a bash script with modular components that worked together to create a custom NixOS image for ChromeOS devices.

## Overview

The old build process was a multi-stage approach that:

1. Extracted necessary components from an existing ChromeOS shim image
2. Built a NixOS system from scratch
3. Combined these components into a new bootable image
4. Patched the initramfs to include a custom bootloader

## Main Components

### 1. Main Script: `build-final-image.sh`

This was the entry point that orchestrated the entire build process. It followed these steps:

1. **Initialization**: Set up configuration variables and logging
2. **Prerequisites Check**: Verified all required tools and files were available
3. **Harvesting**: Extracted kernel, modules, and firmware from the ChromeOS shim
4. **NixOS Build**: Built a minimal NixOS system
5. **Assembly**: Combined all components into the final image
6. **Cleanup**: Removed temporary files and devices

### 2. Library Modules

The build process was modularized into several library files:

#### `common.sh`
- Provided utility functions for logging, error handling, and system operations
- Managed loop devices, mount points, and temporary directories
- Handled privilege escalation with sudo

#### `config.sh`
- Defined all configuration variables with default values
- Specified file paths, partition sizes, and mount points
- Configured systemd version requirements and binary paths

#### `prerequisites.sh`
- Checked if the script was running with appropriate privileges
- Verified all required commands were available
- Validated that required files existed
- Checked for optional recovery image for better hardware support

#### `harvest.sh`
- Extracted kernel modules from the ChromeOS shim
- Harvested firmware files from both shim and recovery images
- Extracted the kernel partition (KERN-A) using cgpt
- Decompressed and extracted the initramfs from the kernel
- Patched the initramfs to include the shimboot bootloader

#### `nixos-build.sh`
- Created a minimal NixOS configuration
- Built the NixOS system using `nixos-generate`
- Prepared the NixOS rootfs for integration

#### `assemble.sh`
- Created a new disk image with proper partition layout
- Copied the kernel, state, and bootloader partitions
- Assembled the root filesystem with NixOS and harvested components
- Set up proper file permissions and ownership

#### `cleanup.sh`
- Provided comprehensive cleanup functions
- Set up traps for graceful exit on errors or interruptions
- Ensured all loop devices were detached and mount points unmounted

## Detailed Build Process

### Phase 1: Initialization and Prerequisites

1. **Configuration Setup**:
   - Set default paths for shim, recovery, kernel, and bootloader files
   - Define partition sizes (STATE: 1MB, KERNEL: 32MB, BOOTLOADER: 32MB)
   - Configure mount points and temporary directories

2. **Environment Validation**:
   - Ensure script is not running as root (will escalate when needed)
   - Verify all required commands are available (nix, cgpt, binwalk, etc.)
   - Check that required files exist (shim.bin, bootloader directory)
   - Optionally check for recovery image for enhanced hardware support

### Phase 2: Harvesting Components

1. **Kernel Module Extraction**:
   - Mount the ChromeOS shim image (partition 3 - ROOT-A)
   - Copy the entire `/lib/modules` directory structure
   - Extract firmware files from `/lib/firmware`

2. **Recovery Image Processing** (if available):
   - Mount the recovery image to harvest additional drivers
   - Merge additional firmware into the previously extracted firmware
   - Copy modprobe configurations for better hardware support

3. **Kernel Partition Extraction**:
   - Use `cgpt` to locate the KERN-A partition (partition 2)
   - Extract the kernel using `dd` with proper offset and size

4. **Initramfs Extraction**:
   - Use `binwalk` to find the gzip-compressed section within the kernel
   - Decompress the kernel to reveal the XZ-compressed initramfs
   - Extract the initramfs using `xz` and `cpio`

5. **Initramfs Patching**:
   - Copy the shimboot bootloader files into the extracted initramfs
   - Modify the init script to execute the bootstrap script
   - Make all bootloader scripts executable

### Phase 3: NixOS System Build

1. **Configuration Creation**:
   - Generate a minimal NixOS configuration file
   - Include essential modules for hardware support
   - Configure basic system settings

2. **System Build**:
   - Use `nixos-generate` to build a minimal NixOS system
   - Create a squashfs filesystem from the built system
   - Prepare the NixOS rootfs for integration

### Phase 4: Image Assembly

1. **Disk Image Creation**:
   - Create a new disk image with proper ChromeOS partition layout
   - Set up partition table with STATE, KERN-A, ROOT-A, and BOOTLOADER partitions
   - Format partitions with appropriate filesystems

2. **Component Integration**:
   - Copy the extracted kernel to the KERN-A partition
   - Copy the state partition from the original shim
   - Copy the bootloader files to the BOOTLOADER partition
   - Assemble the root filesystem with NixOS and harvested components

3. **Filesystem Setup**:
   - Create necessary directory structure
   - Copy kernel modules to `/lib/modules`
   - Copy firmware to `/lib/firmware`
   - Set up proper file permissions and ownership

### Phase 5: Finalization and Cleanup

1. **Image Finalization**:
   - Ensure all files are properly copied and configured
   - Verify the image structure matches ChromeOS expectations
   - Generate final output image (`shimboot_nixos.bin`)

2. **Cleanup**:
   - Unmount all mounted filesystems
   - Detach all loop devices
   - Remove temporary directories
   - Log any warnings or errors encountered

## Key Technical Details

### Partition Layout
The process maintained ChromeOS's standard partition layout:
- **STATE**: Small partition for system state (1MB)
- **KERN-A**: Kernel partition (32MB)
- **ROOT-A**: Root filesystem partition (variable size)
- **BOOTLOADER**: Bootloader partition (32MB)

### Systemd Patching
The build process required a specific version of systemd (257.6) with patches for ChromeOS compatibility. It would fail if the patched systemd binary wasn't found at the expected path.

### Hardware Support
The process extracted and preserved all necessary drivers and firmware from the original ChromeOS image, ensuring compatibility with the device's hardware.

### Boot Process
The patched initramfs would:
1. Execute the original ChromeOS init process
2. Chain-load the shimboot bootstrap script
3. Transition to the NixOS system

## Limitations of the Old Process

1. **Complexity**: The multi-stage process was complex and error-prone
2. **Dependencies**: Required many external tools and precise versions
3. **Maintenance**: Keeping the systemd patches updated was challenging
4. **Debugging**: Issues were difficult to diagnose due to the many moving parts
5. **Reproducibility**: Variations in host systems could affect the build

## Transition to New Method

The old process has been replaced with a more modern, declarative approach using Nix flakes and modules. The new method:

- Uses Nix's native capabilities for system image creation
- Eliminates the need for complex extraction and patching
- Provides better reproducibility and maintainability
- Simplifies the build process significantly

This explanation should serve as a reference for understanding how the original build process worked, which can be helpful for troubleshooting or historical context.