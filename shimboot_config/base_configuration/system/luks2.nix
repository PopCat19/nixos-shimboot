# LUKS2 Encryption Configuration Module
#
# Purpose: Configure LUKS2 encrypted root filesystem support for shimboot
# Dependencies: cryptsetup, kmod
# Related: boot.nix, filesystems.nix, security.nix
#
# This module:
# - Configures initrd to include cryptsetup and required kernel modules
# - Sets up filesystem to expect decrypted mapper device
# - Provides options for LUKS2 configuration customization
# - Integrates with shimboot bootloader LUKS handling
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

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/disk/by-label/nixos-encrypted";
      description = "Path to the LUKS2 encrypted device";
    };

    mapperName = lib.mkOption {
      type = lib.types.str;
      default = "rootfs";
      description = "Name for the decrypted mapper device";
    };

    filesystem = lib.mkOption {
      type = lib.types.enum [
        "ext4"
        "btrfs"
        "xfs"
      ];
      default = "ext4";
      description = "Filesystem type for the decrypted root";
    };

    keyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional keyfile for automatic unlocking";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add cryptsetup to initrd
    boot.initrd = {
      availableKernelModules = [
        "dm-crypt"
        "dm-mod"
        "aesni_intel"
        "cryptd"
      ];

      # Include cryptsetup in initrd for LUKS handling
      extraUtilsCommands = ''
        copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
      '';
    };

    # Configure filesystem for decrypted mapper device
    fileSystems."/" = lib.mkForce {
      device = "/dev/mapper/${cfg.mapperName}";
      fsType = cfg.filesystem;
    };

    # Add cryptsetup to system packages for management
    environment.systemPackages = with pkgs; [
      cryptsetup
    ];
  };
}
