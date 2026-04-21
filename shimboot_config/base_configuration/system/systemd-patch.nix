# systemd-patch.nix
#
# Purpose: Configure systemd package (overridden to 257.9 via flake overlay)
#
# This module:
# - Sets systemd.package from nixpkgs with overlay applied
# - Provides systemd tools system-wide
#
# Systemd version constraint:
# - Ceiling: 257.x (258+ requires kernel >=5.10)
# - Reason: systemd 258+ uses open_tree()/move_mount() syscalls unavailable on
#   older shim kernels (octopus 4.14.x, dedede 5.4.x before certain commits)
# - Ref: https://github.com/ading2210/shimboot/issues/405
#
# Note: The systemd package is overridden in flake.nix via systemdOverlay
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.systemd ];

  systemd.package = pkgs.systemd;
}