# Hyprland Autostart Module
#
# Purpose: Configure applications that start automatically with Hyprland
# Dependencies: None
# Related: environment.nix
#
# This module:
# - Starts hyprpaper wallpaper daemon
# - Launches polkit authentication agent
# - Sets up D-Bus environment
# - Starts hardware-specific services and HyprPanel
{
  wayland.windowManager.hyprland.settings = {
    "exec-once" = [
      "hyprpaper -c ~/.config/hypr/hyprpaper.conf"
      "/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1"

      "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      "dbus-update-activation-environment --systemd --all"
      "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"

      "openrgb -p orang-full"

      # HyprPanel is started via systemd service (see hyprpanel-home.nix)
      # This provides automatic restart on failure
    ];
  };
}
