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
# - Sets up additional tmpfs mounts for volatile directories
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Root filesystem configuration with proper mount options
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # System-wide tmpfs configuration
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "2G";

}
