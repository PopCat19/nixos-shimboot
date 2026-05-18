{ lib, pkgs, ... }:
let
  algorithm = "lzo-rle";
  memPercent = 60;
  swapPriority = 100;
in
{
  # Load zram kernel module at boot
  boot.kernelModules = [ "zram" ];

  # Manual zram swap setup — avoids nixpkgs zram-generator which pulls in a
  # package incompatible with pinned systemd 259.5, causing DEPEND/TIME loops.
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
    path = with pkgs; [ kmod coreutils util-linux ];
    script = ''
      set -e
      # Ensure module loaded
      modprobe zram 2>/dev/null || true
      ZRAM0=/sys/block/zram0
      if [ ! -e "$ZRAM0" ]; then
        echo "zram0: device not found, aborting" >&2
        exit 1
      fi
      # Reset if previously configured
      echo 1 > "$ZRAM0/reset" 2>/dev/null || true
      # Set compression algorithm
      echo "${algorithm}" > "$ZRAM0/comp_algorithm"
      # Calculate size: memPercent of total RAM
      total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
      size_kb=$(( total_kb * ${toString memPercent} / 100 ))
      echo "$(( size_kb * 1024 ))" > "$ZRAM0/disksize"
      # Create and activate swap
      mkswap /dev/zram0
      swapon -p ${toString swapPriority} /dev/zram0
    '';
  };

  services.zram-generator.enable = lib.mkForce false;

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
