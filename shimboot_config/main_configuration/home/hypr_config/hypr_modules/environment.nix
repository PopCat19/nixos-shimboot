# Hyprland Environment Module
#
# Purpose: Set Hyprland-specific environment variables
# Dependencies: None
# Related: autostart.nix
#
# This module:
# - Configures cursor theme and size for Hyprland
# - Sets desktop session identifiers
# - Configures Qt for Wayland
{
  wayland.windowManager.hyprland.settings = {
    env = [
      "HYPRCURSOR_THEME,rose-pine-hyprcursor"
      "XCURSOR_SIZE,24"
      "HYPRCURSOR_SIZE,28"

      "XDG_CURRENT_DESKTOP,Hyprland"
      "XDG_SESSION_TYPE,wayland"
      "XDG_SESSION_DESKTOP,Hyprland"

      "QT_QPA_PLATFORM,wayland;xcb"
      "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
      "QT_AUTO_SCREEN_SCALE_FACTOR,1"

      "QT_STYLE_OVERRIDE,kvantum"
    ];
  };
}
