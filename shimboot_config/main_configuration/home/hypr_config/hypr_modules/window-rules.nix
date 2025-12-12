# Hyprland Window Rules Module
#
# Purpose: Define window behavior rules for specific applications in Hyprland
# Dependencies: theme_config/window-rules.nix
# Related: general.nix
#
# This module:
# - Imports centralized window rules and opacity settings from theme_config
# - Maintains backward compatibility for existing imports
# - Provides window behavior configuration for Hyprland
{...}: {
  imports = [
    ../../theme_config/window-rules.nix
  ];

  wayland.windowManager.hyprland.settings = {
    windowrulev2 = windowRules;
    windowrule = [
      "float,title:^(Open)$"
      "float,title:^(Choose Files)$"
      "float,title:^(Save As)$"
      "float,title:^(Confirm to replace files)$"
      "float,title:^(File Operation Progress)$"
    ];
  };
}
