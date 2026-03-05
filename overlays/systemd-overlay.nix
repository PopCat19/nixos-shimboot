# systemd-overlay.nix
#
# Purpose: Overlay for NixOS configs — pins systemd-minimal to super to break cycle
#
# This module:
# - Builds patched systemd using super (not _self) to break fixed-point cycle
# - Provides systemd override for NixOS configurations
system:
[
  (
    _self: super:
    let
      # Build patched systemd against super.systemd-minimal (not _self)
      # to break the fixed-point cycle
      patchedSystemd = import ./systemd-258.3.nix { pkgs = super; };
    in
    {
      systemd = patchedSystemd;
    }
  )
]
