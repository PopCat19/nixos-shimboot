# Autostart Applications for Hyprland
# ====================================

{
  wayland.windowManager.hyprland.settings = {
    "exec-once" = [
      # Core services
      "hyprpaper"
      "/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1"
      
      # Desktop integration
      "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      "dbus-update-activation-environment --systemd --all"
      "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      
      # Hardware specific
      "/usr/lib/pam_kwallet_init"
      "openrgb -p orang-full"
      
      # Wallpaper (SWWW)
      "swww init"
      "swww img ~/.config/hypr/wallpapers/your-default-wallpaper.jpg"
    ];
  };
}