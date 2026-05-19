# systemd-patch.nix
#
# Purpose: Configure systemd to use pinned 257.9 via overrideAttrs
#
# This module:
# - Sets systemd.package to systemd257 from specialArgs
#
# Systemd version constraint:
# - Ceiling: 259.x (260 requires kernel >= 5.10 with mount_setattr)
# - 257.9 proven working on ChromeOS shim kernels (dedede 5.4.85, octopus 4.14.x)
# - Ref: https://github.com/ading2210/shimboot/issues/405
{
  systemd257,
  lib,
  ...
}:
{
  systemd.package = lib.mkForce systemd257;

  # Suppress oomd — ChromeOS kernel 5.4.85 lacks cgroup v2 PSI
  systemd.suppressedSystemUnits = lib.mkForce [
    "systemd-oomd.service"
    "systemd-oomd.socket"
  ];
}
