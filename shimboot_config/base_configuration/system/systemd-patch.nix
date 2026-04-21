# systemd-patch.nix
#
# Purpose: Apply pinned systemd 257.9 with ChromeOS compatibility patch
#
# This module:
# - Sets systemd.package to the pinned+patched derivation from flake
# - Provides systemd tools system-wide
#
# Systemd version constraint:
# - Ceiling: 257.x (258+ requires kernel >=5.10)
# - Reason: systemd 258+ uses open_tree()/move_mount() syscalls unavailable on
#   older shim kernels (octopus 4.14.x, dedede 5.4.x before certain commits)
# - Ref: https://github.com/ading2210/shimboot/issues/405
{
  pkgs,
  config,
  ...
}:
let
  systemdPkg = config._module.args.patchedSystemd or pkgs.systemd;
in
{
  environment.systemPackages = [ systemdPkg ];

  systemd.package = systemdPkg;
}
