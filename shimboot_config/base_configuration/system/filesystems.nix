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
# - Optimizes mount options to reduce USB disk writes
{ lib, ... }:
{
  # Root filesystem configuration with USB-optimized mount options
  # noatime: skip access time updates (reduces writes, improves read performance)
  # commit=30: journal sync interval in seconds (lower for hard reset safety)
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    options = [
      "noatime"
      "commit=30"
      "errors=remount-ro"
    ];
  };

  # System-wide tmpfs configuration
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "2G";

  # Volatile log directory (complements journald Storage=volatile)
  # Disable by commenting out if debugging requires persistent logs
  fileSystems."/var/log" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=100M"
      "mode=755"
    ];
  };
}
