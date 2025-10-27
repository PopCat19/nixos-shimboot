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

  # Filesystem tuning for ChromeOS devices (often SSDs)
  # Reduce swap usage to prolong SSD lifespan
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;  # Prefer RAM over swap (default: 60)
    "vm.dirty_ratio" = 15;  # Start background writeback at 15% of memory
    "vm.dirty_background_ratio" = 5;  # Start sync at 5% of memory
  };
}
