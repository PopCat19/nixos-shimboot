# Animations Configuration
#
# Purpose: Enable and configure Material Design 3 (MD3) animations
# Dependencies: None
# Related: general.nix
#
# This module:
# - Enables animations
# - Sets MD3 Bezier curves (Standard, Decelerated, Accelerated)
# - Configures window, layer, and workspace transitions
# - Uses fade transitions for special workspaces
{
  wayland.windowManager.hyprland.settings = {
    animations = {
      enabled = true;

      bezier = [
        "linear, 0, 0, 1, 1"
        "md3_standard, 0.2, 0, 0, 1"
        "md3_decel, 0.05, 0.7, 0.1, 1"
        "md3_accel, 0.3, 0, 0.8, 0.15"
        "menu_decel, 0.1, 1, 0, 1"
        "overshot, 0.05, 0.9, 0.1, 1.1"
      ];

      animation = [
        "windows, 1, 3, md3_decel, popin 60%"
        "windowsIn, 1, 3, md3_decel, popin 60%"
        "windowsOut, 1, 3, md3_accel, popin 60%"
        "border, 1, 10, default"
        "fade, 1, 3, md3_decel"
        "layers, 1, 2, md3_decel, slide"
        "layersIn, 1, 3, menu_decel, slide"
        "layersOut, 1, 1.6, menu_decel"
        "fadeLayersIn, 1, 2, menu_decel"
        "fadeLayersOut, 1, 4.5, menu_decel"
        "workspaces, 1, 7, menu_decel, slide"
        "specialWorkspace, 1, 3, md3_decel, fade"
      ];
    };
  };
}
