# LUKS2 Encryption Configuration Module
#
# Purpose: Configure LUKS2 encrypted root filesystem support for shimboot
# Dependencies: cryptsetup, kmod
# Related: boot.nix, filesystems.nix, security.nix
#
# This module:
# - Sets up filesystem to expect decrypted mapper device
# - Provides options for LUKS2 configuration customization
# - Integrates with shimboot bootloader LUKS handling
#
# Note: The shimboot bootloader handles LUKS unlock (not NixOS initrd),
# so boot.initrd settings are intentionally omitted. The bootloader runs
# its own initramfs with bundled cryptsetup.
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

    allowDiscards = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow TRIM/discard on the LUKS device. Improves SSD/eMMC performance
        but may leak filesystem metadata (size/usage patterns) to an attacker
        with physical access.
      '';
    };

    keyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Optional keyfile for automatic unlocking. Path is resolved inside
        the initramfs environment (e.g. /bootloader/opt/luks.key).
      '';
    };

    fallbackToPassword = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If keyFile is set but fails, prompt for passphrase interactively.
        If false, boot halts on keyfile failure.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Override root filesystem to use decrypted mapper device.
    # mkForce overrides filesystems.nix which uses mkDefault.
    fileSystems."/" = lib.mkForce {
      device = "/dev/mapper/rootfs";
      fsType = "ext4";
      options = [
        "noatime"
        "commit=30"
        "errors=remount-ro"
      ];
    };

    # Add cryptsetup to system packages for runtime management
    environment.systemPackages = with pkgs; [
      cryptsetup
    ];
  };
}
