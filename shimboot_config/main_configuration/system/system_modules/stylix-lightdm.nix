# Stylix LightDM Theming Module
#
# Purpose: Configure LightDM theming using Stylix framework
# Dependencies: inputs.stylix (flake input)
# Related: ../home/stylix.nix
#
# This module:
# - Imports Stylix NixOS module for LightDM theming
# - Enables LightDM theming with wallpaper support
# - Works alongside home-level Stylix configuration
{
  inputs,
  ...
}: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  # Enable LightDM theming through Stylix
  stylix.targets.lightdm.enable = true;
  stylix.targets.lightdm.useWallpaper = true;
}