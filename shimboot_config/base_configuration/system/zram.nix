# ZRAM Configuration Module
#
# Purpose: Configure zram swap for ChromeOS compatibility
# Dependencies: kernel modules
# Related: boot.nix, power-management.nix
#
# This module enables:
# - ZRAM swap for improved memory management
# - Fast compression using zstd algorithm
# - Automatic kernel module loading
_: {
  # Enable zram swap
  zramSwap = {
    enable = true;
    algorithm = "lzo-rle";
    memoryPercent = 60;
    priority = 80;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
  };

  services.journald.extraConfig = ''
    RuntimeMaxUse=20M
    SystemMaxUse=50M
  '';
}
