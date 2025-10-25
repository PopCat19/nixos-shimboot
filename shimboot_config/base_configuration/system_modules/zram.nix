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
    algorithm = "lzo";  # Fast, matches upstream
    memoryPercent = 100;  # Use all RAM for swap
    priority = 10;
  };
  
  # Ensure kernel module loads
  boot.kernelModules = [ "zram" ];
}