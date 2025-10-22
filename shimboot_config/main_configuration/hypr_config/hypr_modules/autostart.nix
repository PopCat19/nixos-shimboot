# Autostart Applications for Hyprland
# ====================================
{
  wayland.windowManager.hyprland.settings = {
    "exec-once" = [
      # Core services
      "hyprpaper -c ~/.config/hypr/hyprpaper.conf"
      "/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1"

      # Desktop integration
      "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      "dbus-update-activation-environment --systemd --all"
      "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"

      # Hardware specific
      "openrgb -p orang-full"
    ];
  };
}
