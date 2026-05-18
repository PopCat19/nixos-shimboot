# systemd-patch.nix
#
# Purpose: Configure systemd to use pinned 259.5 with ChromeOS + pidfd_spawn patches
#
# This module:
# - Sets systemd.package to systemd259 from specialArgs
# - Suppresses unit files missing from systemd 259.5 (added in 258+)
#
# Systemd version constraint:
# - Ceiling: 259.x (260 requires kernel >= 5.10)
# - Reason: systemd 258+ requires mount_setattr (kernel 5.12), unavailable on
#   ChromeOS shim kernels. Dedede's 5.4.85 has open_tree/move_mount (5.2) but
#   not mount_setattr, so 259 falls back gracefully; 260's unguarded usage in
#   get_sub_mounts/bind_mount_submounts would also need these on boot path.
# - Ref: https://github.com/ading2210/shimboot/issues/405
{
  systemd259,
  lib,
  ...
}:
{
  systemd.package = lib.mkForce systemd259;

  # Suppress units that don't exist in systemd 259.5 (added in 258+)
  systemd.suppressedSystemUnits = lib.mkForce [
    "systemd-factory-reset-request.service"
    "systemd-factory-reset-reboot.service"
    "factory-reset.target.wants"
  ];
}
