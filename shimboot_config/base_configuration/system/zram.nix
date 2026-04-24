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
{ lib, ... }:
{
  # Enable zram swap - critical for ChromeOS low-memory devices
  zramSwap = {
    enable = lib.mkForce true;
    algorithm = lib.mkForce "lzo-rle";
    memoryPercent = lib.mkForce 50;
    priority = lib.mkForce 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkForce 60;
    "vm.page-cluster" = lib.mkForce 3;
    "vm.oom-kill" = lib.mkForce 1;
    "vm.admin_reserve_kbytes" = lib.mkForce 8192;
    "vm.oom_kill_allocating_task" = lib.mkForce 1;
    "vm.overcommit_memory" = lib.mkForce 0;
    "vm.vfs_cache_pressure" = lib.mkForce 50;
    "vm.dirty_ratio" = lib.mkForce 15;
    "vm.dirty_background_ratio" = lib.mkForce 5;
  };
}
