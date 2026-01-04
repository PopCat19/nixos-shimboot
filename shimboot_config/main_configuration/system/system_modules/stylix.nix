# Stylix System Module
#
# Purpose: Import Stylix NixOS module for system-level theming
# Dependencies: stylix (flake input)
# Related: greeter.nix, ../home/stylix.nix
#
# This module:
# - Imports Stylix NixOS module
# - Provides system-level theming framework
# - Works alongside home-level Stylix configuration
{stylix, ...}: {
  imports = [
    stylix.nixosModules.stylix
  ];
}
