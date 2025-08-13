# Initramfs Patching Specification

## Overview
This document outlines the step-by-step process for extracting, patching, and repackaging a Chrome OS initramfs with custom bootloader files.

## Prerequisites
- Root privileges
- Required tools: binwalk, cpio, pcregrep, cgpt, mkfs.ext4, mkfs.ext2, fdisk, lz4
- Chrome OS shim image
- Bootloader files in `./bootloader/` directory

## Step 1: Extract Kernel from Shim Image
1. Create a loop device for the shim image
2. Copy the kernel partition (KERN-A, typically partition 2) to a temporary file
3. Release the loop device

## Step 2: Extract Initramfs from Kernel
### For x86 Architecture:
1. Use binwalk to extract the gzip compressed kernel image
2. Use binwalk again to extract the initramfs cpio archive from the kernel image
3. Extract the cpio archive to a target directory

### For ARM64 Architecture:
1. Use binwalk to find the LZ4 compressed data offset
2. Extract the LZ4 archive using dd and lz4 decompression
3. Use binwalk to extract the initramfs cpio archive from the decompressed kernel
4. Extract the cpio archive to a target directory

## Step 3: Patch Initramfs
1. Remove the original `init` file from the extracted initramfs
2. Copy all files from `./bootloader/` directory into the initramfs:
   - `bin/init` - Main init script
   - `bin/bootstrap.sh` - Bootloader script with OS selection menu
   - `opt/.shimboot_version` - Version file
   - `opt/crossystem` - Chrome OS system utility
   - `opt/mount-encrypted` - Encrypted partition utility
3. Make all files in the `bin` directory executable

## Step 4: Create Disk Image
1. Calculate required partition sizes:
   - Stateful: 1MB
   - Kernel: 32MB
   - Bootloader: 20MB
   - Rootfs: 20% larger than its contents
2. Create a disk image with the calculated total size
3. Partition the disk with GPT partition table

## Step 5: Create Partitions
1. Format stateful partition (partition 1) as ext4
2. Write the kernel image to kernel partition (partition 2)
3. Set bootable flags on kernel partition
4. Format bootloader partition (partition 3) as ext2
5. Format rootfs partition (partition 4) as ext4 (or LUKS encrypted if enabled)

## Step 6: Populate Partitions
1. Mount stateful partition and create required directory structure
2. Mount bootloader partition and copy patched initramfs contents
3. Mount rootfs partition and copy the Linux distribution files
4. Unmount all partitions

## Step 7: Cleanup
1. Remove any temporary files and directories
2. Release loop devices
3. If LUKS was used, close the encrypted device

## Result
The final disk image contains a patched initramfs that replaces Chrome OS's factory shim with a multi-boot system capable of launching various Linux distributions while maintaining Chrome OS compatibility.