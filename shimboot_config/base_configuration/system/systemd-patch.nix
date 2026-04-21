# systemd-patch.nix
#
# Purpose: Configure systemd to use pinned 257.9 with ChromeOS compatibility patch
#
# This module:
# - Sets systemd.package to systemd257 from specialArgs
# - Provides systemd tools system-wide
#
# Systemd version constraint:
# - Ceiling: 257.x (258+ requires kernel >=5.10)
# - Reason: systemd 258+ uses open_tree()/move_mount() syscalls unavailable on
#   older shim kernels (octopus 4.14.x, dedede 5.4.x before certain commits)
# - Ref: https://github.com/ading2210/shimboot/issues/405
{
  pkgs,
  systemd257,
  ...
}:
{
  environment.systemPackages = [ systemd257 ];

  systemd.package = systemd257;
}