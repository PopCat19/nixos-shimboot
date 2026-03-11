# ZRAM Configuration Module
#
# Purpose: Configure zram swap for ChromeOS compatibility
# Dependencies: kernel modules
# Related: boot.nix, power-management.nix
#
# This module enables:
# - ZRAM swap for improved memory management
# - Fast compression using lzo-rle algorithm
# - Automatic kernel module loading
# - OOM killer configuration for memory pressure handling
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
    "vm.oom-kill" = 1;
    "vm.admin_reserve_kbytes" = 1024;
    "vm.overcommit_memory" = 1;
  };
}
