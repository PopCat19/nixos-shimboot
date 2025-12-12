# Hyprland Colors Module
#
# Purpose: Import Rose Pine color scheme variables for Hyprland
# Dependencies: theme_config/hyprland.nix
# Related: general.nix, window-rules.nix
#
# This module:
# - Imports Hyprland theme configuration from theme_config
# - Provides color variables for other Hyprland modules
# - Maintains backward compatibility for existing imports
{...}: {
  imports = [
    ../../theme_config/hyprland.nix
  ];
}
