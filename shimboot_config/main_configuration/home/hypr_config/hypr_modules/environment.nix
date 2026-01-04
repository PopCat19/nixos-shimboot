# Environment Variables
#
# Purpose: Configure Hyprland-specific environment variables
# Dependencies: None
# Related: system_modules/environment.nix, home_modules/environment.nix
#
# This module:
# - Sets Hyprland session identifiers
# - Configures Qt platform and style settings
# - Defines cursor size
# Note: Cross-DE variables belong in system_modules/environment.nix or home_modules/environment.nix
{
  wayland.windowManager.hyprland.settings = {
    env = [
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
