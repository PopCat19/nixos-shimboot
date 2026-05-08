# systemd-patch.nix
#
# Purpose: Configure systemd to use pinned 257.9 with ChromeOS compatibility patch
#
# This module:
# - Sets systemd.package to systemd257 from specialArgs
# - Suppresses unit files missing from systemd 257.9 (added in 258+)
#
# Systemd version constraint:
# - Ceiling: 259.x (260 requires kernel >= 5.10)
# - Reason: systemd 258+ requires mount_setattr (kernel 5.12), unavailable on
#   ChromeOS shim kernels. Dedede's 5.4.85 has open_tree/move_mount (5.2) but
#   not mount_setattr, so 259 falls back gracefully; 260's unguarded usage in
#   get_sub_mounts/bind_mount_submounts would also need these on boot path.
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
