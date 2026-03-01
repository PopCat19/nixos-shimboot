# LUKS2 Encrypted Root Configuration Module
#
# Purpose: Configure NixOS to expect LUKS2-encrypted root filesystem
#
# This module:
# - Override root device to /dev/mapper/<name> matching bootstrap.sh mapper name
# - Include dm-crypt kernel modules for ChromeOS kernel compatibility
# - Provide cryptsetup in running system for maintenance and re-keying
#
# Encryption is handled pre-pivot by bootstrap.sh in the ChromeOS initramfs,
# NOT by NixOS initrd. This module only configures the post-pivot expectations.
# Build images with: assemble-final.sh --luks
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.shimboot.luks2;
in
{
  options.shimboot.luks2 = {
    enable = lib.mkEnableOption "LUKS2 encrypted root filesystem support";

    mapperName = lib.mkOption {
      type = lib.types.str;
      default = "rootfs";
      description = "Mapper device name (must match bootstrap.sh 'cryptsetup open ... <name>')";
    };

    filesystem = lib.mkOption {
      type = lib.types.enum [
        "ext4"
        "btrfs"
        "xfs"
      ];
      default = "ext4";
      description = "Filesystem type inside the LUKS2 container";
    };
  };

  config = lib.mkIf cfg.enable {
    # dm-crypt modules for ChromeOS kernel — loaded at runtime, not in initrd
    # (ChromeOS initramfs handles unlock before pivot_root)
    boot.kernelModules = [
      "dm-crypt"
      "dm-mod"
      "aesni_intel"
      "cryptd"
      "xts"
      "aes_generic"
    ];

    # Also include in availableKernelModules for initrd generation
    boot.initrd.availableKernelModules = [
      "dm-crypt"
      "dm-mod"
      "aesni_intel"
      "cryptd"
      "xts"
      "aes_generic"
    ];

    # Root device is the opened mapper, not the raw partition label
    fileSystems."/" = lib.mkForce {
      device = "/dev/mapper/${cfg.mapperName}";
      fsType = cfg.filesystem;
      options = [
        "noatime"
        "commit=30"
        "errors=remount-ro"
      ];
    };

    # cryptsetup in running system for re-keying and header backup
    environment.systemPackages = with pkgs; [
      cryptsetup
    ];
  };
}
