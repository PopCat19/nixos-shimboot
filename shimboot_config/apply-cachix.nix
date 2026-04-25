# apply-cachix.nix
#
# Purpose: Apply cachix configuration to NixOS system
#
# This module:
# - Imports cachix values and applies to nix.settings
# - Used by base configuration to apply caches
#
# Consumers should import cachix.nix for values to merge
{ lib, ... }:
let
  cachix = import ./cachix.nix { };
in
{
  nix.settings = lib.mkMerge [
    { inherit (cachix) substituters; }
    { trusted-public-keys = cachix.trustedPublicKeys; }
  ];
}
