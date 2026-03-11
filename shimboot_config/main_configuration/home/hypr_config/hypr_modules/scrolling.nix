# Scrolling Layout Configuration
#
# Purpose: Configure Hyprland scrolling layout plugin
# Dependencies: hyprlandPlugins.hyprscrolling
# Related: keybinds.nix
#
# This module:
# - Enables scrolling layout with column-based window arrangement
# - Configures focus behavior and column sizing
# - Sets up wrap-around and scroll direction
{
  wayland.windowManager.hyprland.settings = {
    scrolling = {
      fullscreen_on_one_column = true;
      column_width = 0.5;
      focus_fit_method = 1;
      follow_focus = true;
      follow_min_visible = 0.4;
      explicit_column_widths = "0.333, 0.5, 0.667, 1.0";
      wrap_focus = true;
      wrap_swapcol = true;
      direction = "right";
    };
  };
}
