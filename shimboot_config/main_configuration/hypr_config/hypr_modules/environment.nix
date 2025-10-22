# Environment Variables for Hyprland (module-scoped)
# ==================================================
# Keep Hyprland-specific/session-tied variables here to preserve modularity.
# Cross-DE or application-global variables should live in:
# - system_modules/environment.nix (system-wide)
# - home_modules/environment.nix (user-wide)
{
  wayland.windowManager.hyprland.settings = {
    env = [
      # Cursor theme (Hyprland cursor integration)
      "HYPRCURSOR_THEME,rose-pine-hyprcursor"
      "XCURSOR_SIZE,24"
      "HYPRCURSOR_SIZE,28"

      # Desktop session identifiers (set for Hyprland session)
      "XDG_CURRENT_DESKTOP,Hyprland"
      "XDG_SESSION_TYPE,wayland"
      "XDG_SESSION_DESKTOP,Hyprland"

      # Qt configuration specific to Wayland sessions in Hyprland
      "QT_QPA_PLATFORM,wayland;xcb"
      "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
      "QT_AUTO_SCREEN_SCALE_FACTOR,1"

      # Qt style (Kvantum)
      "QT_STYLE_OVERRIDE,kvantum"
    ];
  };
}
