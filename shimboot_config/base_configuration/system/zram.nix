# ZRAM Configuration Module
#
# Purpose: Configure ZRAM compressed swap for ChromeOS devices
#
# This module:
# - Loads zram kernel module at boot
# - Uses native nixpkgs zramSwap (zram-generator backed)
# - Sets compression (lzo-rle) and swap priority for memory-constrained hardware
# - Configures VM sysctls for constrained-memory operation
{ lib, ... }:
{
  # Load zram kernel module at boot
  boot.kernelModules = [ "zram" ];

  # Native ZRAM swap via systemd zram-generator
  # Replaces the previous manual /sys/block/zram0 oneshot hack
  zramSwap = {
    enable = lib.mkDefault true;
    algorithm = lib.mkDefault "lzo-rle";
    memoryPercent = lib.mkDefault 60;
    priority = lib.mkDefault 100;
  };

  # VM tuning for ChromeOS memory-constrained hardware
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkForce 60;
    "vm.page-cluster" = lib.mkForce 3;
    "vm.admin_reserve_kbytes" = lib.mkForce 8192;
    "vm.oom_kill_allocating_task" = lib.mkForce 1;
    "vm.overcommit_memory" = lib.mkForce 0;
    "vm.vfs_cache_pressure" = lib.mkForce 50;
    "vm.dirty_ratio" = lib.mkForce 15;
    "vm.dirty_background_ratio" = lib.mkForce 5;
  };
}
