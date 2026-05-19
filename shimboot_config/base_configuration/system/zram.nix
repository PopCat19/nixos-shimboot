# ZRAM Configuration Module
#
# Purpose: Configure ZRAM compressed swap for ChromeOS devices
#
# This module:
# - Loads zram kernel module at boot
# - Manually configures zram swap via /sys/block/zram0
# - Sets lzo-rle compression and swap priority for memory-constrained hardware
# - Configures VM sysctls for constrained-memory operation
#
# Uses manual /sys/block/zram0 setup instead of services.zram-generator
# because the generator binary links to nixpkgs systemd (260.x) which may
# be ABI-incompatible with the pinned systemd 259.5 at runtime.
{ lib, pkgs, ... }:
let
  algorithm = "lzo-rle";
  memPercent = 60;
  swapPriority = 100;
in
{
  # Load zram kernel module at boot
  boot.kernelModules = [ "zram" ];

  # Manual zram swap setup
  systemd.services.zram-setup = {
    description = "Configure zram swap device";
    wantedBy = [ "swap.target" ];
    after = [ "dev-zram0.device" ];
    before = [ "swap.target" ];
    bindsTo = [ "dev-zram0.device" ];
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [
      kmod
      coreutils
      util-linux
    ];
    script = ''
      set -e
      modprobe zram 2>/dev/null || true
      ZRAM0=/sys/block/zram0
      if [ ! -e "$ZRAM0" ]; then
        echo "zram0: device not found" >&2
        exit 1
      fi
      echo 1 > "$ZRAM0/reset" 2>/dev/null || true
      echo "${algorithm}" > "$ZRAM0/comp_algorithm"
      total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
      size_kb=$(( total_kb * ${toString memPercent} / 100 ))
      echo "$(( size_kb * 1024 ))" > "$ZRAM0/disksize"
      mkswap /dev/zram0
      swapon -p ${toString swapPriority} /dev/zram0
    '';
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
