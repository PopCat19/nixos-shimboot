{ self, nixpkgs, ... }:

let
  system = "x86_64-linux";
  pkgs = nixpkgs.legacyPackages.${system};

  # Chrome OS partition type GUIDs
  chromeOSPartitionTypes = {
    kernel = "FE3A2A5D-4F32-41A7-B725-ACCC3285A309";
    rootfs = "3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC";
    data = "0FC63DAF-8483-4772-8E79-3D69D8477DE4"; # Standard Linux data partition
  };

  # Default partition sizes (in MB)
  defaultPartitionSizes = {
    stateful = 1;
    kernel = 32;
    bootloader = 20;
    rootfs = null; # Will be calculated based on contents
  };

  # Create a disk image with Chrome OS-style partition layout
  createChromeOSImage = {
    outputPath,
    kernelPath,
    initramfsDir,
    rootfsDir,
    distroName ? "nixos",
    partitionSizes ? defaultPartitionSizes,
    extraSizeMB ? 100, # Extra space for rootfs beyond content size
  }: let
    # Calculate rootfs size based on contents
    rootfsSizeMB = pkgs.runCommand "calculate-rootfs-size" {} ''
      size=$(du -sm ${rootfsDir} | cut -f1)
      # Make rootfs partition 20% larger than its contents, plus extra space
      echo $((size * 12 / 10 + ${toString extraSizeMB}))
    '';

    # Total image size calculation
    totalSizeMB = pkgs.runCommand "calculate-total-size" {
      inherit rootfsSizeMB;
      statefulSize = toString partitionSizes.stateful;
      kernelSize = toString partitionSizes.kernel;
      bootloaderSize = toString partitionSizes.bootloader;
    } ''
      total=$((statefulSize + kernelSize + bootloaderSize + $(cat $rootfsSizeMB)))
      echo $total
    '';

    # Create the disk image
    diskImage = pkgs.runCommand "create-disk-image" {
      inherit outputPath;
      size = totalSizeMB;
      buildInputs = with pkgs; [ util-linux e2fsprogs ];
    } ''
      # Create sparse disk image
      dd if=/dev/zero of="$outputPath" bs=1M count=$(cat $size) status=progress

      # Create GPT partition table
      parted -s "$outputPath" mklabel gpt

      # Create partitions
      # Partition 1: Stateful (1MB)
      parted -s "$outputPath" mkpart primary ext4 1MiB ${toString partitionSizes.stateful}MiB
      
      # Partition 2: Kernel (32MB)
      parted -s "$outputPath" mkpart primary ${toString partitionSizes.stateful}MiB $((partitionSizes.stateful + partitionSizes.kernel))MiB
      
      # Partition 3: Bootloader (20MB)
      parted -s "$outputPath" mkpart primary $((partitionSizes.stateful + partitionSizes.kernel))MiB $((partitionSizes.stateful + partitionSizes.kernel + partitionSizes.bootloader))MiB
      
      # Partition 4: Rootfs (remaining space)
      parted -s "$outputPath" mkpart primary $((partitionSizes.stateful + partitionSizes.kernel + partitionSizes.bootloader))MiB 100%

      # Set Chrome OS partition attributes using cgpt
      cgpt add -i 1 -t data -l "STATE" "$outputPath"
      cgpt add -i 2 -t kernel -l "kernel" -S 1 -T 5 -P 10 "$outputPath"
      cgpt add -i 3 -t rootfs -l "shimboot_rootfs:${distroName}" "$outputPath"
      cgpt add -i 4 -t data -l "shimboot_rootfs:${distroName}" "$outputPath"

      # Setup loop device
      loop_device=$(losetup -f --show "$outputPath")
      loop_cleanup() {
        if [ -n "$loop_device" ]; then
          losetup -d "$loop_device"
        fi
      }
      trap loop_cleanup EXIT

      # Wait for partition devices to be created
      sleep 2

      # Format partitions
      # Stateful partition (ext4)
      mkfs.ext4 -L STATE "${loop_device}p1" >/dev/null

      # Kernel partition (copy kernel image directly)
      dd if="${kernelPath}" of="${loop_device}p2" bs=1M oflag=sync status=progress

      # Bootloader partition (ext2 for compatibility)
      mkfs.ext2 -L BOOT "${loop_device}p3" >/dev/null

      # Rootfs partition
      # Format as ext4 with Chrome OS-compatible options
      mkfs.ext4 -L ROOTFS -O ^has_journal,^metadata_csum,^64bit -F "${loop_device}p4" >/dev/null
      
      # Mount and copy rootfs
      mkdir -p /mnt/rootfs
      mount "${loop_device}p4" /mnt/rootfs
      cp -ar ${rootfsDir}/. /mnt/rootfs/
      umount /mnt/rootfs

      # Mount and copy bootloader
      mkdir -p /mnt/bootloader
      mount "${loop_device}p3" /mnt/bootloader
      cp -ar ${initramfsDir}/* /mnt/bootloader/
      
      # Add version information
      if [ -d "${initramfsDir}/opt" ]; then
        echo "${self.lastModifiedDate or self.lastModified or "unknown"}" > /mnt/bootloader/opt/.shimboot_version
      fi
      
      umount /mnt/bootloader

      # Clean up
      losetup -d "$loop_device"
      trap - EXIT
    '';

  in diskImage;

  # Create partitions function for use in other modules
  createPartitions = {
    diskImage,
    kernelPath,
    initramfsDir,
    rootfsDir,
    distroName ? "nixos",
  }: pkgs.runCommand "create-partitions" {
    inherit diskImage kernelPath initramfsDir rootfsDir distroName;
    buildInputs = with pkgs; [ util-linux e2fsprogs ];
  } ''
    # Setup loop device
    loop_device=$(losetup -f --show "$diskImage")
    loop_cleanup() {
      if [ -n "$loop_device" ]; then
        losetup -d "$loop_device"
      fi
    }
    trap loop_cleanup EXIT

    # Wait for partition devices to be created
    sleep 2

    # Format partitions
    # Stateful partition (ext4)
    mkfs.ext4 -L STATE "${loop_device}p1" >/dev/null

    # Kernel partition (copy kernel image directly)
    dd if="${kernelPath}" of="${loop_device}p2" bs=1M oflag=sync status=progress

    # Bootloader partition (ext2 for compatibility)
    mkfs.ext2 -L BOOT "${loop_device}p3" >/dev/null

    # Rootfs partition
    # Format as ext4 with Chrome OS-compatible options
    mkfs.ext4 -L ROOTFS -O ^has_journal,^metadata_csum,^64bit -F "${loop_device}p4" >/dev/null
    
    # Mount and copy rootfs
    mkdir -p /mnt/rootfs
    mount "${loop_device}p4" /mnt/rootfs
    cp -ar ${rootfsDir}/. /mnt/rootfs/
    umount /mnt/rootfs

    # Mount and copy bootloader
    mkdir -p /mnt/bootloader
    mount "${loop_device}p3" /mnt/bootloader
    cp -ar ${initramfsDir}/* /mnt/bootloader/
    
    # Add version information
    if [ -d "${initramfsDir}/opt" ]; then
      echo "${self.lastModifiedDate or self.lastModified or "unknown"}" > /mnt/bootloader/opt/.shimboot_version
    fi
    
    umount /mnt/bootloader

    # Clean up
    losetup -d "$loop_device"
    trap - EXIT

    touch $out
  '';

in {
  # Export functions for use in other modules
  inherit createChromeOSImage createPartitions chromeOSPartitionTypes defaultPartitionSizes;
  
  # Export as a NixOS module
  nixosModules.partitioning = { config, lib, pkgs, ... }: {
    options.shimboot.partitioning = {
      enable = lib.mkEnableOption "Chrome OS-style partitioning";
      distroName = lib.mkOption {
        type = lib.types.str;
        default = "nixos";
        description = "Name of the Linux distribution for partition labels";
      };
      partitionSizes = lib.mkOption {
        type = lib.types.attrs;
        default = defaultPartitionSizes;
        description = "Partition sizes in MB";
      };
    };
  };
  
  # Export packages
  packages.${system} = {
    inherit createChromeOSImage createPartitions;
  };
}