# Autostart Applications
#
# Purpose: Configure applications and services to launch on Hyprland startup
# Dependencies: polkit-gnome-authentication-agent-1, openrgb
# Related: environment.nix
#
# This module:
# - Starts core system services (polkit agent)
# - Configures desktop environment integration
# - Launches systemd user services
# - Initializes hardware-specific applications
{
  wayland.windowManager.hyprland.settings = {
    "exec-once" = [
      "/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1"
      "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      "dbus-update-activation-environment --systemd --all"
      "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      "systemctl --user start hyprpolkitagent"
      "openrgb -p orang-full"
    ];
  };
}
