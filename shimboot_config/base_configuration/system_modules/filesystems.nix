# Filesystem Configuration Module
#
# Purpose: Configure filesystems for single-partition ChromeOS setup
# Dependencies: systemd, util-linux
# Related: boot.nix, hardware.nix
#
# This module:
# - Forces root filesystem to use /dev/disk/by-label/nixos
# - Removes separate /boot partition (not needed in shimboot)
# - Configures tmpfs for /tmp with size limits
{
  config,
  pkgs,
  lib,
  ...
}: {
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  systemd.mounts = [
    {
      what = "tmpfs";
      where = "/tmp";
      type = "tmpfs";
      options = "defaults,size=2G";
    }
  ];

  # Optional squashfs mount for compressed /nix/store
  fileSystems."/nix/store" = lib.mkIf (builtins.pathExists "/nix/.ro-store/store.squashfs") {
    device = "/nix/.ro-store/store.squashfs";
    fsType = "squashfs";
    options = [ "ro" "loop" ];
    neededForBoot = true;
  };
}
