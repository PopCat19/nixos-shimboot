# Environment Variables for Hyprland
# ==================================

{
wayland.windowManager.hyprland.settings = {
  env = [
    # Cursor theme
    "HYPRCURSOR_THEME,rose-pine-hyprcursor"
    "XCURSOR_SIZE,24"
    "HYPRCURSOR_SIZE,28"

    # Desktop session
    "XDG_CURRENT_DESKTOP,Hyprland"
    "XDG_SESSION_TYPE,wayland"
    "XDG_SESSION_DESKTOP,Hyprland"

    # Qt configuration
    "QT_QPA_PLATFORM,wayland;xcb"
    "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
    "QT_AUTO_SCREEN_SCALE_FACTOR,1"

    # Application compatibility
    "MOZ_ENABLE_WAYLAND,1"
    "GDK_SCALE,1"
  ];
};
}