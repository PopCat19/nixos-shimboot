# systemd-patch.nix
#
# Purpose: Apply pinned systemd 258.3 with ChromeOS compatibility patch
#
# This module:
# - Sets systemd.package to the pinned+patched derivation from flake
# - Provides systemd tools system-wide
{
  pkgs,
  patchedSystemd ? null,
  ...
}:
let
  systemdPkg = if patchedSystemd != null then patchedSystemd else pkgs.systemd;
in
{
  environment.systemPackages = [ systemdPkg ];

  systemd.package = systemdPkg;
}
