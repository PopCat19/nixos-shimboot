# ZRAM Configuration Module
#
# Purpose: Configure zram swap for ChromeOS compatibility
# Dependencies: kernel modules
# Related: boot.nix, power-management.nix
#
# This module enables:
# - ZRAM swap for improved memory management
# - Fast compression using lzo algorithm
# - Automatic kernel module loading
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Enable zram swap
  zramSwap = {
    enable = true;
    algorithm = "lzo"; # fastest for your scale
    memoryPercent = 75;
    priority = 100;
  };

  # Ensure kernel module loads
  boot.kernelModules = ["zram"];

  boot.kernel.sysctl = {
    "vm.swappiness" = 45;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 3;
  };
}
