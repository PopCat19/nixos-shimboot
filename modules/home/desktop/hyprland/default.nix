# Hyprland Configuration
#
# Purpose: Hyprland window manager configuration
# Dependencies: hypr_config/hyprland.nix, hypr_config/hypr_packages.nix
# Related: modules/home/desktop
#
# This module:
# - Imports Hyprland main configuration
# - Imports Hyprland packages
# - Provides Hyprland-specific settings
{
  imports = [
    ./hypr_config/hyprland.nix
    ./hypr_config/hypr_packages.nix
  ];
}
