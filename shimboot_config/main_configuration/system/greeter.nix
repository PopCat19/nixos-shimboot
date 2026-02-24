# Greeter Module
#
# Purpose: Configure LightDM greeter theming
# Dependencies: stylix (via stylix.nix module)
# Related: stylix.nix, ../home/stylix.nix
#
# This module:
# - Enables LightDM greeter theming with wallpaper support
# - Works alongside home-level Stylix configuration
{
  # Enable LightDM greeter theming through Stylix
  stylix.targets.lightdm.enable = true;
  stylix.targets.lightdm.useWallpaper = true;
}
