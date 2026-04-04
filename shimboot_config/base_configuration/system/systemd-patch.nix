# systemd-patch.nix
#
# Purpose: Apply pinned systemd 258.3 with ChromeOS compatibility patch
#
# This module:
# - Sets systemd.package to the pinned+patched derivation from flake
# - Provides systemd tools system-wide
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
