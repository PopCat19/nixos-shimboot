# systemd-patch.nix
#
# Purpose: Configure systemd to use pinned 257.9 with ChromeOS compatibility patch
#
# This module:
# - Sets systemd.package to systemd257 from specialArgs
# - Suppresses unit files missing from systemd 257.9 (added in 258+)
#
# Systemd version constraint:
# - Ceiling: 257.x (258+ requires kernel >=5.10)
# - Reason: systemd 258+ uses open_tree()/move_mount() syscalls unavailable on
#   older shim kernels (octopus 4.14.x, dedede 5.4.x before certain commits)
# - Ref: https://github.com/ading2210/shimboot/issues/405
{
  systemd257,
  lib,
  ...
}:
{
  systemd.package = lib.mkForce systemd257;

  # Suppress units that don't exist in systemd 257.9 (added in 258+)
  systemd.suppressedSystemUnits = lib.mkForce [
    "systemd-factory-reset-request.service"
    "systemd-factory-reset-reboot.service"
    "factory-reset.target.wants"
  ];
}
